.PHONY: install uninstall check status clean config install-presets

# Project variables
PROJECT_NAME = nemo2obsidian
BIN_DIR = $(HOME)/.local/bin
NEMO_SCRIPTS_DIR = $(HOME)/.local/share/nemo/scripts


preset:
	@echo ${PROJECT_NAME}
	@echo ${NEMO_SCRIPTS_DIR}

install: check config install-presets
	ln -sf $(PWD)/read_files.sh $(NEMO_SCRIPTS_DIR)/read_files.sh