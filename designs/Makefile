#
####
#########
##################

# The PRJ DIR should be defined for creating the vivado project
DESIGN_PRJ_DIR ?= $(VIVADO_PRJ_DIR)/$(DESIGN_NAME)
MODE ?= tcl
# FPGA_PART ?= xc7k325tffg900-2
FPGA_PART ?= xcvu37p-fsvh2892-3-e-es1
DEBUG ?= 0

include ./$(DESIGN_NAME)/$(DESIGN_NAME).mk

.PHONY: create open synth clean bleach

# TODO: CHECK if this is necessary
bladerunner_setup:
	$(MAKE) -C $(BSG_BLADERUNNER_DIR) setup-uw

f1_hardware:
	$(MAKE) -C ${HARDWARE_PATH} hardware

create: $(DESIGN_NAME).log

$(DESIGN_NAME).log: f1_hardware
	$(MAKE) -C ${HARDWARE_PATH} hardware
	vivado -mode $(MODE) -log $@ -source create_project.tcl \
	-tclargs $(DESIGN_NAME) $(DESIGN_PRJ_DIR) $(FPGA_PART) $(DEBUG) \
	$(words $(VINCLUDES)) $(words $(VHEADERS)) $(words $(VSOURCES)) \
	$(VINCLUDES) $(VHEADERS) $(VSOURCES)

open:
	vivado -mode $(MODE) -log $@ $(DESIGN_PRJ_DIR)/$(DESIGN_NAME).xpr

clean:
	rm -rf vivado.*
	rm -rf $(DESIGN_NAME).log

bleach: clean
	rm -rf $(DESIGN_PRJ_DIR)/$(DESIGN_NAME).xpr
	rm -rf $(DESIGN_PRJ_DIR)/$(DESIGN_NAME)*
