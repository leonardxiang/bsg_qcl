DESINS_TARGETS = f1_manycore

.DEFAULT_GOAL := help

.PHONY: help create_prj open_prj clean bleach bleach_all %.bleach

create_prj:
	$(MAKE) -C designs create DESIGN_NAME=$(DESIGN_NAME)

open_prj:
	$(MAKE) -C designs open DESIGN_NAME=$(DESIGN_NAME)

install_sw:
	$(MAKE) -C designs software DESIGN_NAME=$(DESIGN_NAME)

uninstall_sw:
	$(MAKE) -C designs remove_sw DESIGN_NAME=$(DESIGN_NAME)

bleach_all: $(addsuffix .bleach,$(DESINS_TARGETS))
%.bleach:
	$(MAKE) -C designs bleach DESIGN_NAME=$(basename $@)

help:
	@echo "Usage:"
	@echo "make {create_prj|open_prj|build_software|clean|bleach|bleach_all}"
	@echo "      create_prj:   Create a new Vivado project"
	@echo "      open_prj:     Open a existing Vivado project"
	@echo	"      install_sw:   Install the software of DESIGN_NAME (sudo -E)"
	@echo	"      uninstall_sw: Uninstall the software of DESIGN_NAME (sudo -E)"		
	@echo "      clean:        Clear Vivado logs"
	@echo "      bleach:       Remove the project files of DESIGN_NAME"
	@echo "      bleach_all:   Remove all project files"
