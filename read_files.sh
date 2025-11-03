#!/usr/bin/env bash

# CONFIGURATION
vault_where_files_must_be_opened="/home/msfz751/obsidian/default/"
subtrees_that_must_be_mirrored_in_vault=(
"$HOME/Downloads/metadata/assets/DEJMarApr22vg"
)

# Utility functions
get_linked_files() {
	# Also create symlinks to local files, like images, to which the Markdown file links
	md_dir="$(dirname "$1")"
	# Obsidian 1.0.0 doesn't display <img src="..."> but perhaps a future version will
	sed -En -e 's/.*\[[^]]*\]\(([^"]+)[^)]*\).*/\1/p' \
			-e 's/.*<img[^>]* src="([^?"]+)("|\?).*/\1/p' <"$1" |
		while IFS= read -r linktext
		do
			linked_file="$(readlink -f "$md_dir/${linktext% }" || \
				readlink "$md_dir/${linktext% }")"  # on macOS 10.15 -f is not allowed
			# is it really a local file, and not higher up in the file tree?
			if [[ $? &&  "$linked_file" == "$md_dir"* ]]
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
