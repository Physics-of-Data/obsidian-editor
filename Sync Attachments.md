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
    const content = await app.vault.read(currentFile);

    // Find all attachment links (images and PDFs)
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
            // Standard markdown - path is relative or absolute
            vaultAttachmentPath = path.join(vaultPath, decodedPath);

            if (!fs.existsSync(vaultAttachmentPath)) {
                // Try relative to current file location
                const noteDir = path.dirname(filePath);
                vaultAttachmentPath = path.join(noteDir, decodedPath);
            }

            if (!fs.existsSync(vaultAttachmentPath)) {
                console.log(`⚠️ Skipping ${decodedPath} - not found in vault`);
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
        new Notice(`✅ Synced ${movedCount} attachment(s) to filesystem` +
                   (skippedCount > 0 ? ` (${skippedCount} already synced)` : ''));
    } else {
        new Notice(`ℹ️ No attachments needed syncing` +
                   (skippedCount > 0 ? ` (${skippedCount} already synced)` : ''));
    }

    return "";
}

await syncAttachments();
_%>
