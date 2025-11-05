<%*
// Templater script to sync Obsidian attachments back to filesystem
// Bind this template to Alt+U via Hotkeys
//
// This script:
// 1. Finds all attachments (images, PDFs) referenced in the current note
// 2. Moves them from the vault to the filesystem location
// 3. Creates symlinks in the vault pointing to the real files
// 4. Updates markdown links to use relative paths

const fs = require('fs');
const path = require('path');

async function syncAttachments() {
    // Get the current file
    const currentFile = tp.file.find_tfile(tp.file.path(true));
    if (!currentFile) {
        new Notice("❌ No active file found");
        return "";
    }

    const vaultPath = app.vault.adapter.basePath;
    const filePath = path.join(vaultPath, currentFile.path);

    // Check if the current file is a symlink
    const stats = fs.lstatSync(filePath);
    if (!stats.isSymbolicLink()) {
        new Notice("❌ This file is not a symlink. Only works with files opened via Obsieditor.sh");
        return "";
    }

    // Read the symlink to get the real filesystem path
    const realMarkdownPath = fs.readlinkSync(filePath);
    const realDir = path.dirname(realMarkdownPath);
    const noteBaseName = path.basename(realMarkdownPath, '.md');

    // Read the file content
    let content = await app.vault.read(currentFile);

    // STEP 1: Fix any markdown links that still have spaces (from Typora edits)
    // This ensures all links are properly encoded before we process attachments
    let fixedContent = content;
    let spacesFixed = 0;

    // Fix standard markdown links: ![...](path with spaces)
    fixedContent = fixedContent.replace(/\]\(([^)]+)\)/g, (match, path) => {
        if (path.includes(' ') && !path.includes('%20')) {
            spacesFixed++;
            return '](' + path.replace(/ /g, '%20') + ')';
        }
        return match;
    });

    // Fix HTML img src: src="path with spaces"
    fixedContent = fixedContent.replace(/src="([^"]+)"/g, (match, path) => {
        if (path.includes(' ') && !path.includes('%20')) {
            spacesFixed++;
            return 'src="' + path.replace(/ /g, '%20') + '"';
        }
        return match;
    });

    if (spacesFixed > 0) {
        console.log(`🔧 Fixed ${spacesFixed} link(s) with spaces`);
        await app.vault.modify(currentFile, fixedContent);
        content = fixedContent;  // Update content for further processing
    }

    // STEP 1.5: Fix basename-only links for files moved to note-named subfolders
    // This handles the case where images are moved in Obsidian to subfolders but
    // the markdown link doesn't get updated with the path prefix
    let basenameFixedContent = content;
    let basenamesFixed = 0;

    // Check if a note-named assets subfolder exists in the vault
    const vaultMirroredBase = path.join(vaultPath, realDir.substring(1)); // Remove leading /
    const vaultMirroredAssets = path.join(vaultMirroredBase, 'assets');
    const noteNamedSubfolder = path.join(vaultMirroredAssets, noteBaseName);

    if (fs.existsSync(noteNamedSubfolder)) {
        console.log(`📂 Found note-named subfolder: ${noteNamedSubfolder}`);

        // Get all files in the note-named subfolder
        const { execSync } = require('child_process');
        try {
            // Use -type l for symlinks since files in vault are symlinked to filesystem
            const findCmd = `find "${noteNamedSubfolder}" \\( -type f -o -type l \\) \\( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" -o -name "*.pdf" -o -name "*.webp" \\) 2>/dev/null`;
            const filesInSubfolder = execSync(findCmd, { encoding: 'utf8' }).trim();

            if (filesInSubfolder) {
                const fileList = filesInSubfolder.split('\n');
                console.log(`📋 Found ${fileList.length} file(s) in note-named subfolder`);

                // For each file, get its basename
                const basenameMap = {};
                fileList.forEach(filePath => {
                    const basename = path.basename(filePath);
                    basenameMap[basename] = filePath;
                });

                // Find basename-only links in the markdown (no path prefix)
                // Match ![...](filename.ext) where filename has no / or \
                const basenameOnlyRegex = /!\[([^\]]*)\]\(([^)\/\\]+\.(png|jpg|jpeg|gif|svg|pdf|webp))\)/gi;
                const basenameMatches = [...basenameFixedContent.matchAll(basenameOnlyRegex)];

                console.log(`🔍 Found ${basenameMatches.length} basename-only link(s) in markdown`);

                for (const match of basenameMatches) {
                    const fullMatch = match[0];
                    const altText = match[1];
                    const basenameLink = match[2];

                    // Decode %20 to spaces for comparison
                    const decodedBasename = basenameLink.replace(/%20/g, ' ');

                    // Check if this basename exists in the note-named subfolder
                    if (basenameMap[decodedBasename]) {
                        // The file exists in vault's note-named subfolder but link is basename-only
                        // We need to: 1) Move file in filesystem, 2) Update vault symlink, 3) Fix markdown link

                        const vaultFilePath = basenameMap[decodedBasename];

                        // Determine where the file should be in filesystem
                        const filesystemSubfolder = path.join(realDir, 'assets', noteBaseName);
                        const newFilesystemPath = path.join(filesystemSubfolder, decodedBasename);

                        // Check if vault file is a symlink to filesystem
                        const vaultFileStats = fs.lstatSync(vaultFilePath);
                        if (vaultFileStats.isSymbolicLink()) {
                            // Read where the symlink currently points
                            const currentFilesystemPath = fs.readlinkSync(vaultFilePath);

                            // Only update if symlink is not already pointing to correct location
                            if (currentFilesystemPath !== newFilesystemPath) {
                                // Create subfolder in filesystem if it doesn't exist
                                if (!fs.existsSync(filesystemSubfolder)) {
                                    fs.mkdirSync(filesystemSubfolder, { recursive: true });
                                    console.log(`📁 Created filesystem subfolder: ${filesystemSubfolder}`);
                                }

                                // Move file in filesystem if source exists and target doesn't
                                if (fs.existsSync(currentFilesystemPath) && !fs.existsSync(newFilesystemPath)) {
                                    fs.renameSync(currentFilesystemPath, newFilesystemPath);
                                    console.log(`📦 Moved file: ${path.basename(currentFilesystemPath)} -> ${filesystemSubfolder}/`);
                                } else if (fs.existsSync(newFilesystemPath)) {
                                    console.log(`⏭️ File already exists at target location: ${newFilesystemPath}`);
                                } else {
                                    console.log(`⚠️ Source file not found at: ${currentFilesystemPath}`);
                                }

                                // Update the symlink to point to new location (only if target exists)
                                if (fs.existsSync(newFilesystemPath)) {
                                    fs.unlinkSync(vaultFilePath);
                                    fs.symlinkSync(newFilesystemPath, vaultFilePath);
                                    console.log(`🔗 Updated symlink to new location`);
                                }
                            }
                        }

                        // Update the markdown link to include the path prefix
                        const encodedNoteName = noteBaseName.replace(/ /g, '%20');
                        const correctPath = `assets/${encodedNoteName}/${basenameLink}`;
                        const newLink = `![${altText}](${correctPath})`;

                        basenameFixedContent = basenameFixedContent.replace(fullMatch, newLink);
                        basenamesFixed++;
                        console.log(`🔧 Fixed basename link: ${basenameLink} -> ${correctPath}`);
                    }
                }
            }
        } catch (error) {
            console.log(`⚠️ Error scanning note-named subfolder: ${error.message}`);
        }
    }

    if (basenamesFixed > 0) {
        console.log(`🔧 Fixed ${basenamesFixed} basename-only link(s)`);
        await app.vault.modify(currentFile, basenameFixedContent);
        content = basenameFixedContent;  // Update content for further processing
    }

    // STEP 2: Find all attachment links (images and PDFs)
    // Handles both:
    // 1. Standard markdown: ![alt](path) or <img src="path">
    // 2. Obsidian wiki-links: ![[filename]]
    const standardRegex = /!\[([^\]]*)\]\(([^)]+)\)|<img[^>]* src="([^"]+)"/g;
    const wikiLinkRegex = /!\[\[([^\]]+?\.(png|jpg|jpeg|gif|svg|pdf|webp))\]\]/gi;

    const standardMatches = [...content.matchAll(standardRegex)];
    const wikiLinkMatches = [...content.matchAll(wikiLinkRegex)];

    const totalMatches = standardMatches.length + wikiLinkMatches.length;

    if (totalMatches === 0) {
        new Notice("ℹ️ No attachments found in this note");
        console.log("No attachment matches found in content");
        return "";
    }

    console.log(`Found ${totalMatches} attachment reference(s) in markdown:`);
    console.log(`  - ${standardMatches.length} standard markdown links`);
    console.log(`  - ${wikiLinkMatches.length} Obsidian wiki-links`);

    standardMatches.forEach((m, i) => {
        console.log(`  Standard ${i + 1}. ${m[2] || m[3]}`);
    });
    wikiLinkMatches.forEach((m, i) => {
        console.log(`  Wiki ${i + 1}. ![[${m[1]}]]`);
    });

    // Base assets directory in filesystem (we'll determine subdirectories per file)
    const baseAssetsDir = path.join(realDir, 'assets');
    if (!fs.existsSync(baseAssetsDir)) {
        fs.mkdirSync(baseAssetsDir, { recursive: true });
        console.log(`✅ Created base assets directory: ${baseAssetsDir}`);
    }

    let movedCount = 0;
    let skippedCount = 0;
    let updatedContent = content;

    // Helper function to process an attachment
    const processAttachment = (attachmentPath, isWikiLink, originalMatch) => {
        // Decode %20 to spaces
        const decodedPath = attachmentPath.replace(/%20/g, ' ');

        // For wiki-links, the path is just the filename - search in vault's attachment folders
        let vaultAttachmentPath;

        if (isWikiLink) {
            // Wiki-links reference files by name - search vault recursively
            const { execSync } = require('child_process');

            try {
                // Use find to search the entire vault for the file
                const findCmd = `find "${vaultPath}" -type f -name "${decodedPath.replace(/"/g, '\\"')}" 2>/dev/null`;
                const result = execSync(findCmd, { encoding: 'utf8' }).trim();

                if (result) {
                    // Take the first match if multiple found
                    vaultAttachmentPath = result.split('\n')[0];
                    console.log(`🔍 Found wiki-link file via search: ${vaultAttachmentPath}`);
                } else {
                    console.log(`⚠️ Skipping wiki-link ![[${decodedPath}]] - not found in vault`);
                    skippedCount++;
                    return;
                }
            } catch (error) {
                console.log(`⚠️ Error searching for wiki-link ![[${decodedPath}]]:`, error.message);
                skippedCount++;
                return;
            }
        } else {
            // Standard markdown - check filesystem first (Typora), then vault (Obsidian)
            const filesystemCheckPath = path.join(realDir, decodedPath);

            if (fs.existsSync(filesystemCheckPath)) {
                // File exists in filesystem (added by Typora)
                // Create symlink in vault if it doesn't exist
                const vaultTargetPath = path.join(vaultPath, realDir.substring(1), decodedPath);
                const vaultTargetDir = path.dirname(vaultTargetPath);

                if (!fs.existsSync(vaultTargetDir)) {
                    fs.mkdirSync(vaultTargetDir, { recursive: true });
                    console.log(`✅ Created vault directory: ${vaultTargetDir}`);
                }

                if (!fs.existsSync(vaultTargetPath)) {
                    fs.symlinkSync(filesystemCheckPath, vaultTargetPath);
                    console.log(`🔗 Created symlink in vault: ${vaultTargetPath} -> ${filesystemCheckPath}`);
                    movedCount++;
                } else {
                    const stats = fs.lstatSync(vaultTargetPath);
                    if (stats.isSymbolicLink()) {
                        console.log(`⏭️ Skipping ${decodedPath} - symlink already exists`);
                        skippedCount++;
                    }
                }
                return;  // Done with this file
            }

            // File not in filesystem, check vault (Obsidian case)
            vaultAttachmentPath = path.join(vaultPath, decodedPath);

            if (!fs.existsSync(vaultAttachmentPath)) {
                // Try relative to current file location
                const noteDir = path.dirname(filePath);
                vaultAttachmentPath = path.join(noteDir, decodedPath);
            }

            if (!fs.existsSync(vaultAttachmentPath)) {
                console.log(`⚠️ Skipping ${decodedPath} - not found in vault or filesystem`);
                skippedCount++;
                return;
            }
        }

        console.log(`📁 Found attachment: ${vaultAttachmentPath}`);

        // Check if it's already a symlink (already processed)
        const fileStats = fs.lstatSync(vaultAttachmentPath);
        if (fileStats.isSymbolicLink()) {
            console.log(`⏭️ Skipping ${decodedPath} - already a symlink`);
            skippedCount++;
            return;
        }

        // Determine the filesystem path based on where the file is in the vault
        const fileName = path.basename(vaultAttachmentPath);

        // Check if file is in the mirrored directory structure
        const vaultMirroredBase = path.join(vaultPath, realDir.substring(1)); // Remove leading /
        const vaultMirroredAssets = path.join(vaultMirroredBase, 'assets');

        let filesystemPath;
        let relativePath;

        // If file is in the mirrored structure's assets folder (pasted in Obsidian)
        if (vaultAttachmentPath.startsWith(vaultMirroredAssets + path.sep)) {
            // Get the relative path from the mirrored assets folder
            const relativeFromMirroredAssets = vaultAttachmentPath.substring(vaultMirroredAssets.length + 1);
            filesystemPath = path.join(baseAssetsDir, relativeFromMirroredAssets);
            relativePath = path.join('assets', relativeFromMirroredAssets);

            // Create subdirectory if needed
            const targetDir = path.dirname(filesystemPath);
            if (!fs.existsSync(targetDir)) {
                fs.mkdirSync(targetDir, { recursive: true });
                console.log(`✅ Created subdirectory: ${targetDir}`);
            }
        } else {
            // Default: file goes directly in assets folder
            filesystemPath = path.join(baseAssetsDir, fileName);
            relativePath = path.join('assets', fileName);
        }

        console.log(`📍 Target filesystem path: ${filesystemPath}`);
        console.log(`📍 Relative markdown path: ${relativePath}`);

        try {
            // Copy file to filesystem (can't rename across filesystems)
            fs.copyFileSync(vaultAttachmentPath, filesystemPath);
            console.log(`📦 Copied: ${fileName} -> ${filesystemPath}`);

            // Delete original file in vault
            fs.unlinkSync(vaultAttachmentPath);
            console.log(`🗑️ Deleted original: ${vaultAttachmentPath}`);

            // Create symlink in vault pointing to filesystem (use absolute path)
            fs.symlinkSync(filesystemPath, vaultAttachmentPath);
            console.log(`🔗 Created symlink: ${vaultAttachmentPath} -> ${filesystemPath}`);

            // Update the markdown link
            const relativePathEncoded = relativePath.replace(/ /g, '%20');

            if (isWikiLink) {
                // Convert wiki-link to standard markdown with relative path
                updatedContent = updatedContent.replace(
                    `![[${attachmentPath}]]`,
                    `![](${relativePathEncoded})`
                );
            } else {
                // Replace standard markdown link path
                updatedContent = updatedContent.replace(
                    new RegExp(attachmentPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'),
                    relativePathEncoded
                );
            }

            movedCount++;
        } catch (error) {
            console.error(`❌ Error processing ${fileName}:`, error);
            new Notice(`❌ Error processing ${fileName}: ${error.message}`);
        }
    };

    // Process standard markdown links
    for (const match of standardMatches) {
        const attachmentPath = match[2] || match[3];
        if (attachmentPath) {
            processAttachment(attachmentPath, false, match[0]);
        }
    }

    // Process wiki-links
    for (const match of wikiLinkMatches) {
        const attachmentPath = match[1];  // The filename from ![[filename]]
        if (attachmentPath) {
            processAttachment(attachmentPath, true, match[0]);
        }
    }

    // Update the file content if changes were made
    if (movedCount > 0) {
        await app.vault.modify(currentFile, updatedContent);
        let message = `✅ Synced ${movedCount} attachment(s) to filesystem`;
        if (skippedCount > 0) message += ` (${skippedCount} already synced)`;
        if (spacesFixed > 0) message += ` • Fixed ${spacesFixed} space(s)`;
        if (basenamesFixed > 0) message += ` • Fixed ${basenamesFixed} path(s)`;
        new Notice(message);
    } else if (spacesFixed > 0 || basenamesFixed > 0) {
        let message = '✅ ';
        const fixes = [];
        if (spacesFixed > 0) fixes.push(`Fixed ${spacesFixed} space(s)`);
        if (basenamesFixed > 0) fixes.push(`Fixed ${basenamesFixed} path(s)`);
        message += fixes.join(' • ');
        if (skippedCount > 0) message += ` • ${skippedCount} already synced`;
        new Notice(message);
    } else {
        new Notice(`ℹ️ No changes needed` +
                   (skippedCount > 0 ? ` (${skippedCount} already synced)` : ''));
    }

    return "";
}

await syncAttachments();
_%>
