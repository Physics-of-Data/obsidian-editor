# FEATURES

## New Feature: Create New Markdown Files

### Feature
Added ability to create new markdown files directly from the command line using `-n` or `--new` flags.

### Usage

```bash
# Create a new file
Obsieditor.sh -n "My New Note.md"
Obsieditor.sh --new "Project Ideas.md"

# Create file with spaces in name
Obsieditor.sh -n "Meeting Notes 2024.md"

# Automatically adds .md extension if missing
Obsieditor.sh -n "TODO"  # Creates TODO.md

# Open existing file (no flag needed)
Obsieditor.sh "existing.md"
```

### Implementation

```bash
# Parse arguments for --new/-n flag
create_new=false
files_to_process=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		-n|--new)
			create_new=true
			shift
			;;
		*)
			files_to_process+=("$1")
			shift
			;;
	esac
done

# Create new file if flag is set
if [[ "$create_new" == true && ! -f "$file" ]]; then
	# Ensure .md extension
	if [[ "$file" != *.md ]]; then
		file="${file}.md"
	fi

	# Create parent directory if needed
	parent_dir="$(dirname "$file")"
	if [[ ! -d "$parent_dir" ]]; then
		mkdir -p "$parent_dir"
	fi

	# Create file with basic header
	cat > "$file" << EOF
# $(basename "$file" .md)

EOF
fi
```

### Features
- ✅ Automatically adds `.md` extension if missing
- ✅ Creates parent directories if needed
- ✅ Adds basic header with filename as title
- ✅ Immediately opens in Obsidian after creation
- ✅ Works with filenames containing spaces
- ✅ Supports multiple files at once