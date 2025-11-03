.PHONY: install uninstall check status clean config install-presets

# Project variables
PROJECT_NAME = nemo2obsidian
BIN_DIR = $(HOME)/.local/bin
NEMO_SCRIPTS_DIR = $(HOME)/.local/share/nemo/scripts
SCRIPT = Obsieditor.sh

preset:
	@echo ${PROJECT_NAME}
	@echo ${NEMO_SCRIPTS_DIR}

install: check config install-presets
	ln -sf $(PWD)/${SCRIPT} $(NEMO_SCRIPTS_DIR)/${SCRIPT}