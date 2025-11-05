# Obsieditor.sh Quick Start Guide

## Overview

This toolset allows you to edit markdown files from anywhere on your filesystem using Obsidian, while keeping the files and their attachments in their original locations.

## Installation

1. Place `Obsieditor.sh` in `/storage/develop/utils/obsidian-editor/`
2. Make it executable: `chmod +x Obsieditor.sh`
3. Copy `Sync Attachments.md` to `~/obsidian/default/Templates/`
4. Configure Templater hotkey (see below)

## Basic Workflow

### Opening Files

```bash
# Open existing markdown file
./Obsieditor.sh ~/Documents/MyNote.md

# Create and open new file
./Obsieditor.sh -n ~/Documents/NewNote.md
./Obsieditor.sh --new "~/Documents/My New Note.md"
```

### What Happens:
1. Script creates backup: `MyNote.bkup.md`
2. Fixes spaces in markdown links (converts to `%20`)
3. Creates symlink in vault: `~/obsidian/default/home/user/Documents/MyNote.md`
4. Creates symlinks for attachments (images, PDFs)
5. Reloads Obsidian automatically
6. Opens the file in Obsidian

## Syncing Attachments Back to Filesystem

When you paste images or PDFs in Obsidian, they're saved to `~/obsidian/default/assets/`. To move them back to the filesystem:

### Setup (One-time)

1. Open Obsidian → **Settings** → **Hotkeys**
2. Search for: "Templater: Replace templates in the active file"
3. Set hotkey to: **Alt+U**
4. Save

### Usage

1. Open a note with attachments in Obsidian
2. Press **Alt+U**
3. The script will:
   - Move attachments from vault to `~/Documents/assets/[Note Name]/`
   - Create symlinks in vault pointing back to real files
   - Update markdown links to use relative paths
   - Show notification with results

## File Structure Example

**Before opening in Obsidian:**
```
~/Documents/
  └── Project Ideas.md
```

**After opening with Obsieditor.sh:**
```
~/Documents/
  ├── Project Ideas.md              (original file)
  └── Project Ideas.bkup.md         (backup)

~/obsidian/default/
  └── home/msfz751/Documents/
      └── Project Ideas.md          (symlink → original)
```

**After pasting images in Obsidian:**
```
~/obsidian/default/
  └── assets/
      ├── image-20251104172437165.png
      └── report.pdf
```

**After pressing Alt+U:**
```
~/Documents/
  ├── Project Ideas.md
  ├── Project Ideas.bkup.md
  └── assets/Project Ideas/
      ├── image-20251104172437165.png    (real file)
      └── report.pdf                     (real file)

~/obsidian/default/
  ├── home/msfz751/Documents/
  │   └── Project Ideas.md               (symlink → original)
  └── assets/
      ├── image-20251104172437165.png    (symlink → filesystem)
      └── report.pdf                     (symlink → filesystem)
```

## Markdown Link Handling

The script automatically handles spaces in filenames:

**In the markdown file:**
```markdown
![](assets/Project%20Ideas/image-20251104172437165.png)
![](assets/Project%20Ideas/report.pdf)
```

**On the filesystem:**
```
assets/Project Ideas/image-20251104172437165.png
assets/Project Ideas/report.pdf
```

**Important**: Only spaces are encoded as `%20`. Commas, periods, and other characters remain unchanged.

## Troubleshooting

### Files not appearing in Obsidian
- The script automatically reloads the vault
- If still not visible, manually press `Ctrl+P` → "Reload app without saving"

### Alt+U says "not a symlink"
- Only works with files opened via `Obsieditor.sh`
- Regular files in the vault won't work

### Attachments not moving
- Check console (`Ctrl+Shift+I`) for errors
- Verify file permissions
- Ensure files aren't already symlinks (already processed)

### Wrong vault reloads
- Script identifies vaults by matching window titles
- If multiple vaults open, ensure window title contains " - vault_name - "

## Dependencies

- `perl`: For markdown link processing
- `xdg-open` (Linux) or `open` (macOS): For opening Obsidian URIs
- `xdotool` (Linux only): For automated Obsidian reload
- `readlink`: For resolving file paths
- Obsidian with Templater plugin installed

## Benefits

✅ Edit filesystem files in Obsidian without moving them
✅ Automatic backup creation
✅ Automatic vault reload
✅ Proper handling of spaces and special characters
✅ Attachments accessible from both Obsidian and external editors (Typora, etc.)
✅ Works across multiple vaults
✅ Cross-platform (Linux and macOS)

## Advanced Usage

### Creating Notes with Directory Structure

```bash
# Creates parent directories automatically
./Obsieditor.sh -n ~/Documents/Projects/2025/Q1/Planning.md
```

### Batch Opening

```bash
# Open multiple files (not all at once)
./Obsieditor.sh ~/Documents/Note1.md
./Obsieditor.sh ~/Documents/Note2.md
./Obsieditor.sh ~/Documents/Note3.md
```

### Integration with File Manager

You can set `Obsieditor.sh` as the default handler for `.md` files in your file manager.

**Example for Linux (using xdg):**
1. Create desktop entry: `~/.local/share/applications/obsieditor.desktop`
2. Set as default: `xdg-mime default obsieditor.desktop text/markdown`

## Additional Documentation

- [TEMPLATER-SETUP.md](TEMPLATER-SETUP.md) - Detailed Templater configuration
- [BUGS.md](BUGS.md) - Complete list of bugs fixed and technical details
- [Obsieditor.sh](Obsieditor.sh) - Main script with inline comments
- [Sync Attachments.md](Sync Attachments.md) - Templater template source code
