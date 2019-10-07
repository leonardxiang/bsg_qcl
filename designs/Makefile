#
####
#########
##################
DESIGN_NAME ?= f1_manycore

# The PRJ DIR should be defined for creating the vivado project
DESIGN_PRJ_DIR ?= $(VIVADO_PRJ_DIR)/$(DESIGN_NAME)
MODE ?= tcl
# FPGA_PART ?= xc7k325tffg900-2
FPGA_PART ?= xcvu37p-fsvh2892-3-e-es1
DEBUG ?= 0

include ./$(DESIGN_NAME)/$(DESIGN_NAME)_hw.mk
include ./$(DESIGN_NAME)/$(DESIGN_NAME)_sw.mk

.PHONY: hardware create open synth remove_sw clean bleach

.DEFAULT_GOAL := help
help:
	@echo "Usage:"
	@echo "make {hardware|software|create|open|clean|bleach}"
	@echo "      hardware: prepare for creating the hardware"
	@echo "      software: install softwares for this design (sudo user)"
	@echo "      create: create the vivado project of this design"
	@echo "      clean: remove all vivado log files (sudo user)"
	@echo "      bleach: remove all vivado project files"

create: $(DESIGN_NAME).log

$(DESIGN_NAME).log: hardware
	vivado -mode $(MODE) -log $@ -source create_project.tcl \
	-tclargs $(DESIGN_NAME) $(DESIGN_PRJ_DIR) $(FPGA_PART) $(DEBUG) \
	$(words $(VINCLUDES)) $(words $(VHEADERS)) $(words $(VSOURCES)) \
	$(VINCLUDES) $(VHEADERS) $(VSOURCES)

open:
	vivado -mode $(MODE) -log $@ $(DESIGN_PRJ_DIR)/$(DESIGN_NAME).xpr

clean: remove_sw
	rm -rf vivado.*
	rm -rf vivado_*
	rm -rf open*
	rm -rf $(DESIGN_NAME).log

bleach: clean
	rm -rf $(DESIGN_PRJ_DIR)/$(DESIGN_NAME).xpr
	rm -rf $(DESIGN_PRJ_DIR)/$(DESIGN_NAME)*
