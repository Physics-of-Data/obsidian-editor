#!/usr/bin/env bash
# Shell script that make Obsidian act as a markdown editor for files
# outside a vault. Based on this macOS script:
# https://forum.obsidian.md/t/have-obsidian-be-the-handler-of-md-files-add-ability-to-use-obsidian-as-a-markdown-editor-on-files-outside-vault-file-association/314/155?u=msfz751

# Usage:
#   Obsieditor.sh <file.md>           # Open existing file
#   Obsieditor.sh -n <file.md>        # Create and open new file
#   Obsieditor.sh --new <file.md>     # Create and open new file

# CONFIGURATION
# create a default vault with a1ll JS goodies and plugins
vault_where_files_must_be_opened="$HOME/obsidian/default/"
subtrees_that_must_be_mirrored_in_vault=(
)


# Get vault names from obsidian.json as an array
mapfile -t all_vaults < <(awk -F':|,|{|}|"' '{for(i=1;i<=NF;i++)if($i=="path")print$(i+3)}'\
   <"$HOME/.config/obsidian/obsidian.json")

default_vault="$(readlink -f "$vault_where_files_must_be_opened")" || \
    default_vault="$(readlink "$vault_where_files_must_be_opened")" || \
    default_vault="$(sed -E 's/.*"path":"([^"]+)",.*"open":true.*/\1/'\
   <"$HOME/.config/obsidian/obsidian.json")"  # currently active vault




fix_markdown_links() {
	# Fix markdown file to encode only spaces (not commas or other chars) in links
	local md_file="$1"

	# Use perl to find and encode ONLY spaces in markdown links
	# Obsidian only requires spaces to be encoded as %20, other chars remain as-is
	perl -i.bak -pe '
		# Fix markdown-style links: ![...](path with spaces)
		s{\]\(([^)]+)\)}{
			my $path = $1;
			if ($path =~ / / && $path !~ /%20/) {
				$path =~ s/ /%20/g;
			}
			"](" . $path . ")";
		}ge;

		# Fix HTML img src: src="path with spaces"
		s{src="([^"]+)"}{
			my $path = $1;
			if ($path =~ / / && $path !~ /%20/) {
				$path =~ s/ /%20/g;
			}
			"src=\"" . $path . "\"";
		}ge;
	' "$md_file"

	# Remove backup file created by perl -i
	rm -f "${md_file}.bak"
	logger "OPEN-IN-OBSIDIAN: Encoded spaces in paths for $md_file"
}



get_linked_files() {
	# create symlinks to support files, like images, PDF files to which the Markdown file links
	local md_dir="$(dirname "$1")"
	local link_dir="$2"

	# Use mapfile to read all links into an array.
	# 1st line for links of the kind ![image](assets/note_name/image.png)
	# 2nd line for links <img src="assets/note_name/image.png" alt="image" style="zoom:80%;" />
    mapfile -t links < <(sed -En -e 's/.*!*\[[^]]*\]\(([^)]+)\).*/\1/p' \
                            -e 's/.*<img[^>]* src="([^?"]+)("|\?).*/\1/p' "$1")

	for linktext in "${links[@]}"
	do
		# Skip empty links
		[[ -z "$linktext" ]] && continue

		# Decode %20 back to spaces for filesystem operations
		# The markdown has %20, but filesystem needs actual spaces
		local decoded_link="${linktext//%20/ }"

		# Resolve the linked file path - must quote to handle spaces
		local linked_file=""
		if [[ -e "$md_dir/$decoded_link" ]]; then
			linked_file="$(readlink -f "$md_dir/$decoded_link" 2>/dev/null || \
				readlink "$md_dir/$decoded_link" 2>/dev/null)"
		else
			logger "OPEN-IN-OBSIDIAN warning: Linked file not found: $md_dir/$decoded_link"
		fi

		# is it really a local file, and not higher up in the file tree?
		if [[ -n "$linked_file" && "$linked_file" == "$md_dir"* ]]
		then
			# Create symlinks with ORIGINAL names (spaces, not %20)
			# Only the markdown content has %20, not the filesystem
			local abs_dir="$(dirname "$linked_file")"
			local target_dir="$link_dir"

			if [[ "$md_dir" != "$abs_dir" ]]
			then
				# Get the relative subdir path (with actual spaces)
				local rel_subdir="${abs_dir#$md_dir}"
				target_dir="$link_dir$rel_subdir"
				mkdir -p "$target_dir"
			fi

			# Use the original filename (with spaces)
			local original_filename=$(basename "$linked_file")
			local linkpath="$target_dir/$original_filename"

			if [[ ! -e "$linkpath" ]]; then
				ln -s "$linked_file" "$linkpath"
				logger "OPEN-IN-OBSIDIAN: Created symlink for '$linkpath'"
			fi
		fi
	done
}


open_file() {
	# Thanks, https://stackoverflow.com/a/75300235/7840347
	url_encoded="$(perl -e 'use URI; print URI->new("'"$1"'");')"
	if [[ -z $url_encoded ]]; then url_encoded="$1"; fi   # in case perl returns nothing

	# Use xdg-open on Linux, open on macOS
	if command -v xdg-open &> /dev/null; then
		xdg-open "obsidian://open?path=$url_encoded"
	elif command -v open &> /dev/null; then
		open "obsidian://open?path=$url_encoded"
	else
		logger "OPEN-IN-OBSIDIAN error: Neither xdg-open nor open command found"
		return 1
	fi
}


reload_obsidian() {
	# Reload Obsidian vault to show newly created symlinks
	# Target the specific vault window by matching the vault name in the window title
	vault_name="$(basename "$1")"

	# Obsidian window titles format: "Note Name - Vault Name - Obsidian v..."
	# We need to match " - vault_name - " to ensure we get the right vault
	window_id=""
	while IFS= read -r wid; do
		window_title=$(xdotool getwindowname "$wid")
		# Match the vault name between " - " delimiters to avoid partial matches
		if [[ "$window_title" =~ \ -\ $vault_name\ -\  ]]; then
			window_id="$wid"
			break
		fi
	done < <(xdotool search --class "obsidian")

	if [[ -z "$window_id" ]]; then
		# Fallback: if we can't find by exact match, try the first obsidian window
		window_id=$(xdotool search --class "obsidian" | head -n 1)
		logger "OPEN-IN-OBSIDIAN warning: Could not find window for vault '$vault_name', using fallback"
	fi

	if [[ -n "$window_id" ]]; then
		# Activate the specific window and execute reload command
		xdotool windowactivate --sync "$window_id" key --clearmodifiers ctrl+p
		sleep 0.3
		xdotool type --clearmodifiers "Reload app without saving"
		sleep 0.3
		xdotool key Return
		sleep 0.5
	else
		logger "OPEN-IN-OBSIDIAN warning: Could not find any Obsidian window"
	fi
}


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

# If no files provided, show usage
if [[ ${#files_to_process[@]} -eq 0 ]]; then
	echo "Usage: $(basename "$0") [-n|--new] <file.md> [file2.md ...]"
	echo ""
	echo "Options:"
	echo "  -n, --new    Create new file(s) if they don't exist"
	echo ""
	echo "Examples:"
	echo "  $(basename "$0") existing.md"
	echo "  $(basename "$0") -n new_note.md"
	echo "  $(basename "$0") --new 'My New Note.md'"
	exit 1
fi

for file in "${files_to_process[@]}"
do
	# If create_new flag is set and file doesn't exist, create it
	if [[ "$create_new" == true && ! -f "$file" ]]; then
		# Ensure .md extension
		if [[ "$file" != *.md ]]; then
			file="${file}.md"
		fi

		# Create parent directory if needed
		parent_dir="$(dirname "$file")"
		if [[ ! -d "$parent_dir" ]]; then
			mkdir -p "$parent_dir"
			logger "OPEN-IN-OBSIDIAN: Created directory $parent_dir"
		fi

		# Create empty markdown file with a basic header
		cat > "$file" << EOF
# $(basename "$file" .md)

EOF
		logger "OPEN-IN-OBSIDIAN: Created new file $file"
		echo "Created new file: $file"
	fi

    # check for existence and readability
	if [[ (! -f "$file") || (! -r "$file") ]]
	then
		logger "OPEN-IN-OBSIDIAN warning: No readable file $file"
		continue
	fi
	abspath=$(readlink -f "$file" || readlink "$file")  # on macOS 10.15 -f is not allowed

	# Create a backup of the markdown file and fix links with spaces
	if [[ "$abspath" == *.md ]]
	then
		backup_path="${abspath%.md}.bkup.md"
		cp "$abspath" "$backup_path"
		logger "OPEN-IN-OBSIDIAN: Created backup at $backup_path"

		# URL-encode any paths with spaces in the markdown file
		fix_markdown_links "$abspath"
	fi

	# 1. If the file is inside any vault (in place or linked), just open it
	for v in "${all_vaults[@]}"
	do
		foundpath="$(find -L "$v" -samefile "$abspath" -and ! -path "*/.trash/*")"
		if [[ $foundpath ]]
		then
			open_file "$foundpath"
			continue 2  # next input file
		fi
	done

	# 2. If the file is in one of the folders that should be mirrored,
	#    replicate the folder's internal directory chain in the vault
	#    and put a link to the file in it; then open that
	for asset_folder in "${subtrees_that_must_be_mirrored_in_vault[@]}"
	do
        linkpath="$default_vault/$(basename "$asset_folder")${abspath#$asset_folder}"
		if [[ "$abspath" == "$asset_folder"* ]]
		then
			linkpath="$default_vault/$(basename "$asset_folder")${abspath#$asset_folder}"
			mkdir -p "$(dirname "$linkpath")"
			ln -s "$abspath" "$linkpath"			
			get_linked_files "$abspath" "$(dirname "$linkpath")"
			sleep 1  # delay for Obsidian to notice the new file(s)
			reload_obsidian "$default_vault"
			sleep 1
			open_file "$linkpath"
			continue 2
		fi
	done    
	
	# 3. In other cases, replicate the note's FULL directory structure in the vault
	# Remove leading / from absolute path
	relative_path="${abspath#/}"

	linkpath="$default_vault/$relative_path"
	mkdir -p "$(dirname "$linkpath")"

	# If the exact symlink already exists, just open it
	if [[ -L "$linkpath" && "$(readlink -f "$linkpath" 2>/dev/null || readlink "$linkpath")" == "$abspath" ]]; then
		open_file "$linkpath"
		continue
	fi

	# If something else exists at this location, create a unique name
	while [[ -e "$linkpath" ]]
	do
		linkpath="${linkpath%.*}_$RANDOM.${linkpath##*.}"
	done

	ln -s "$abspath" "$linkpath"
	get_linked_files "$abspath" "$(dirname "$linkpath")"
	sleep 1
	reload_obsidian "$default_vault"
	sleep 1
	open_file "$linkpath" 
done
