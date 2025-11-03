#!/usr/bin/env bash

# CONFIGURATION
vault_where_files_must_be_opened="/home/msfz751/obsidian/default/"
subtrees_that_must_be_mirrored_in_vault=(
"$HOME/Downloads/metadata/assets/DEJMarApr22vg"
)

# Main script
# IFS=$'\n' all_vaults=($(awk -F':|,|{|}|"' '{for(i=1;i<=NF;i++)if($i=="path")print$(i+3)}'\
#    <"$HOME/.config/obsidian/obsidian.json"))
all_vaults=$(awk -F':|,|{|}|"' '{for(i=1;i<=NF;i++)if($i=="path")print$(i+3)}'\
   <"$HOME/.config/obsidian/obsidian.json")

default_vault="$(readlink -f "$vault_where_files_must_be_opened")" || \
    default_vault="$(readlink "$vault_where_files_must_be_opened")" || \
    # on macOS 10.15 -f is not allowed with readlink
    default_vault="$(sed -E 's/.*"path":"([^"]+)",.*"open":true.*/\1/'\
   <"$HOME/.config/obsidian/obsidian.json")"  # currently active vault




get_linked_files() {
	# Also create symlinks to local files, like images, to which the Markdown file links
	md_dir="$(dirname "$1")"
	
	# Use mapfile to read all links into an array
    mapfile -t links < <(sed -En -e 's/.*!*\[[^]]*\]\(([^)]+)\).*/\1/p' \
                            -e 's/.*<img[^>]* src="([^?"]+)("|\?).*/\1/p' "$1")
	
	for linktext in "${links[@]}"
	do
		# URL decode the path (handle %20, %2F, etc.)
		decoded_link=$(printf '%b' "${linktext//%/\\x}")
		
		linked_file="$(readlink -f "$md_dir/$decoded_link" 2>/dev/null || \
			readlink "$md_dir/$decoded_link" 2>/dev/null)"
		
		# is it really a local file, and not higher up in the file tree?
		if [[ -n "$linked_file" && "$linked_file" == "$md_dir"* ]]
		then
			link_dir=$2
			# create subdirs if needed
			abs_dir="$(dirname "$linked_file")"
			if [[ "$md_dir" != "$abs_dir" ]]
			then
				link_dir="$link_dir${abs_dir#$md_dir}"
				mkdir -p "$link_dir"
			fi
			linkpath="$link_dir/$(basename "$linked_file")"
			[[ ! -e "$linkpath" ]] && ln -s "$linked_file" "$linkpath"
		fi
	done
}


open_file() {
	# Thanks, https://stackoverflow.com/a/75300235/7840347
	url_encoded="$(perl -e 'use URI; print URI->new("'"$1"'");')"
	if [[ -z $url_encoded ]]; then url_encoded="$1"; fi   # in case perl returns nothing
	open "obsidian://open?path=$url_encoded"
}

for file in "$@"
do

    # check for existence and readability
	if [[ (! -f "$file") || (! -r "$file") ]]
	then
		logger "OPEN-IN-OBSIDIAN warning: No readable file $file"
		continue
	fi
	abspath=$(readlink -f "$file" || readlink "$file")  # on macOS 10.15 -f is not allowed

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
        # zenity --info --title "Base" --text "$asset_folder, $(basename "$asset_folder")"
        # zenity --info --title "abspath" --text "$abspath"
        linkpath="$default_vault/$(basename "$asset_folder")${abspath#$asset_folder}"
        # zenity --info --title "linkpath" --text "$linkpath"
		if [[ "$abspath" == "$asset_folder"* ]]
		then
			linkpath="$default_vault/$(basename "$asset_folder")${abspath#$asset_folder}"
            # zenity --info --title "Selected" --text "$linkpath"
			mkdir -p "$(dirname "$linkpath")"
			ln -s "$abspath" "$linkpath"			
			get_linked_files "$abspath" "$(dirname "$linkpath")"
			sleep 1  # delay for Obsidian to notice the new file(s)
			open_file "$linkpath"
			continue 2
		fi
	done    

	# 3. In other cases, create a uniquely named symlink in the Temp folder and open it
	mkdir -p "$default_vault/Temp"
	filename="$(basename "$abspath")"
	linkpath="$default_vault/Temp/$filename"

    # zenity --info --title "Selected" --text "$linkpath"

	while [[ -e "$linkpath" ]]  # don't overwrite existing symlinks: choose a unique name
	do
		linkpath="${linkpath%.*}_$RANDOM.${linkpath##*.}"
	done
	ln -s "$abspath" "$linkpath"
	get_linked_files "$abspath" "$default_vault/Temp"
	sleep 1
	open_file "$linkpath"    
	    
done
