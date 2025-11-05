# Templater Script Setup: Sync Attachments to Filesystem

## Purpose

This Templater script **Sync Attachments.md** syncs attachments (images, PDFs) from the Obsidian vault back to the filesystem, allowing them to be accessible by external editors like Typora.

## How It Works

### The Problem
1. You create a markdown file: `~/Documents/Project Ideas.md`
2. `obsieditor` creates a symlink: `~/obsidian/default/$HOME/Documents/Project Ideas.md`
3. You paste images/PDFs in Obsidian
4. Attachments are saved to: `~/obsidian/default/assets/`
5. **Problem**: Typora can't access them because they only exist in the vault

### The Solution
When you press **Alt+U**, invoking the template, the script:
1. Finds all attachments referenced in the current note
2. Moves them from `~/obsidian/default/assets/` to `~/Documents/assets/Project Ideas/`
3. Creates symlinks in the vault pointing to the real files
4. Updates markdown links to use relative paths

### Result
- Attachments now exist in the filesystem
- Obsidian still sees them via symlinks
- Typora can access them
- Both editors work with the same files!

## Installation

### Step 1: Install Templater Plugin

1. Open Obsidian
2. Go to **Settings** → **Community plugins**
3. Turn off **Restricted mode** if needed
4. Click **Browse** and search for "Templater"
5. Install and Enable "Templater"

### Step 2: Create Templates Folder

1. In your vault (`~/obsidian/default/`), create a folder called `Templates`. I chose `Extras/Templates`, for instance
2. Or use an existing templates folder

### Step 3: Add the Template File

1. Copy `Sync Attachments.md` to your templates folder
2. Full path: `~/obsidian/default/Extras/Templates/Sync Attachments.md`

### Step 4: Configure Templater

1. Go to **Settings** → **Templater**
2. Under **Template folder location**, set it to `Extras/Templates`
3. Enable **Trigger Templater on new file creation** (optional)

### Step 5: Set Up Hotkey

1. Go to **Settings** → **Hotkeys**
2. Search for "Templater: Replace templates in the active file"
3. Set hotkey to **Alt+U**
4. Save

**Note**: This uses the "Replace templates" command, not "Execute User Script". The template will execute when you press Alt+U in any note.

## Usage

1. Open a markdown note that has attachments (images, PDFs)
2. Press **Alt+U**
3. The script will:
   - Move attachments to `~/Documents/assets/[Note Name]/`
   - Create symlinks in the vault
   - Update markdown links
   - Show notification with results

## Example

**Before**:
```
~/Documents/Project Ideas.md  (original file)
~/obsidian/default/$HOME/Documents/Project Ideas.md  (symlink)
~/obsidian/default/assets/image-20251104172437165.png  (real file)
~/obsidian/default/assets/asy_latex-1_0.pdf  (real file)
```

**After pressing Alt+U**:
```
~/Documents/Project Ideas.md  (original file)
~/Documents/assets/Project Ideas/image-20251104172437165.png  (real file)
~/Documents/assets/Project Ideas/asy_latex-1_0.pdf  (real file)
~/obsidian/default/$HOME/Documents/Project Ideas.md  (symlink)
~/obsidian/default/assets/image-20251104172437165.png  (symlink → filesystem)
~/obsidian/default/assets/asy_latex-1_0.pdf  (symlink → filesystem)
```

## Markdown Link Updates

**Before**:
```markdown
![](assets/image-20251104172437165.png)
![](asy_latex-1_0.pdf)
```

**After**:
```markdown
![](assets/Project%20Ideas/image-20251104172437165.png)
![](assets/Project%20Ideas/asy_latex-1_0.pdf)
```

## Troubleshooting

### Script doesn't run
- Check that Templater is enabled
- Check that the hotkey is set
- Verify the script path in Templater settings

### Hotkey doesn't work
- Go to Settings → Hotkeys
- Search for the script name
- Assign Alt+U to it

### Files not moving
- Check console (Ctrl+Shift+I) for error messages
- Verify file permissions
- Ensure the original markdown file is a symlink (not a real file in the vault)

### Attachments still in vault
- The script only moves files that aren't already symlinks
- If a file is already a symlink, it's been processed before

## Notes

- The script only processes attachments that aren't already symlinks
- It automatically creates the `assets/[Note Name]/` directory structure
- Spaces in filenames are URL-encoded in markdown links (`%20`)
- The script works with both markdown image syntax and HTML img tags
- We use `assets` to get closer to the denomination that Typora uses
