# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-05

### Added
- Initial beta release of obseditor script
- Support for opening external markdown files in Obsidian
- Automatic symlink creation for linked resources (images, PDFs)
- Recreation of original folder structure in Obsidian vault
- Multiple file selection support from file explorer (Nemo and Nautilus)
- Command-line interface - can be run from terminal
- Create new files with `-n` or `--new` flag
- Automatic URL encoding of spaces in markdown links (%20)
- Backup creation before modifying markdown files
- Templater template `Sync Attachments.md` to synchronize additions, modifications, and insertions between Obsidian and external editors
- Integration with Typora for seamless image handling
- Makefile for easy installation
- Comprehensive documentation (README, QUICK-START, FEATURES, BUGS, TEMPLATER-SETUP)

### Credits
- Based on original macOS script by [@bvdg](https://forum.obsidian.md/u/bvdg) from the Obsidian forums
- Adapted for Linux (CachyOS/GNOME/Nemo) by msfz751

