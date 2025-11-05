Borrowing some ideas from the script here, I have made some minor modifications for use in Linux. I use CachyOS with GNOME,and Nemo as File Explorer. Thanks @ bvdg

I copy this script to $HOME/.local/share/nemo/scripts. You could do the same in Nautilus. Then, I just select the markdown note that I want to edit in Obsidian from the context menu, and I get the note and its attached files all in an Obsidian vault. I created a dummy vault for this purpose - I called it “default”, although you can bring off-vault notes to the vault of your preference. You set that in vault_where_files_must_be_opened variable at the top.

The trick is creating symbolic links of the original .md file and its linked resources, such as images, PDF files, etc. What you have in Obsidian are all symbolic links. Once you finish your editing (text wrangling, formatting, tables, etc.), you could delete the files from the vault. The original files will persists since they are just inodes.

The main change I made on the original script is that instead of creating a Temp folder inside the vault for the outside notes, I recreate the original folder structure where the note was residing. So, it would look to something like this:

I found that this folder structure is more informative of the note, or notes, I am dealing with, while providing context of location.

The script is ready for selection of multiple MD files; it will loop for file in "$@" through every markdown note in the file explorer creating all the necessary symbolic links.

I know it is not a perfect solution but it works. It can serve other purposes as well, such as note importer, or modified, to be a CLI note editor.

Enjoy!

Notes

    I usually start markdown notes with Typora with some bare content. Then, I use this script to bring it to Obsidian, to edit it with Obsidian superpowers: plugins, custom JavaScript scripts, advanced tables, formatting, etc. For instance, Typora only supports live embedding for images, while Obsidian natively supports embedding and viewing PDF files.
    To make the transition of images (links) to Obsidian set your Typora preferences to use “relative paths”


