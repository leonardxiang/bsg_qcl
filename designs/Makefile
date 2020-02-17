#
####
#########
##################
include ../environment.mk
$(info $(shell echo -e "$(ORANGE)### USE QCL REPO DIR: ###$(NC)"))
$(info $(shell echo -e "$(ORANGE)==================================>$(NC)"))
$(info $(shell echo -e "$(ORANGE)$(QCL_REPO_DIR)$(NC)"))
$(info $(shell echo -e "$(ORANGE)<==================================$(NC)"))

QCL_DESIGN_NAME ?= qmc_runner
TEST_NAME ?= loopback_demodulate

SYNTH_MODE = 1

include $(QCL_DESIGN_NAME)/hw.mk
include $(QCL_DESIGN_NAME)/sw.mk

MODE ?= tcl
DEBUG ?= 0

LOGFILE_PATH := $(VIVADO_PRJ_DIR)/$(QCL_DESIGN_NAME)
QCL_DESIGN_PRJECT := $(VIVADO_PRJ_DIR)/$(QCL_DESIGN_NAME)/$(QCL_DESIGN_NAME).xpr
SIM_TCL_FILE := $(QCL_DESIGN_NAME)/sim.tcl
SYNTH_TCL_FILE := $(QCL_DESIGN_NAME)/synth.tcl

$(LOGFILE_PATH)/vivado_setup.log: hardware
	vivado -mode $(MODE) -log $@ -source create_project.tcl \
	-tclargs $(QCL_DESIGN_NAME) $(QCL_DESIGN_PATH) $(VIVADO_PRJ_DIR) $(FPGA_PART) \
	$(DEBUG) $(words $(VINCLUDES)) $(words $(VHEADERS)) $(words $(VSOURCES)) \
	$(VINCLUDES) $(VHEADERS) $(VSOURCES)

$(LOGFILE_PATH)/rtlsim.log: $(LOGFILE_PATH)/vivado_setup.log
	make testbench
	vivado -mode $(MODE) -log $@ $(QCL_DESIGN_PRJECT) \
	-source $(SIM_TCL_FILE) \
	-tclargs $(QCL_DESIGN_NAME) $(QCL_DESIGN_PATH)

$(LOGFILE_PATH)/synth.log:
	vivado -mode $(MODE) -log $@ $(QCL_DESIGN_PRJECT) \
	-source $(SYNTH_TCL_FILE) \
	-tclargs $(QCL_DESIGN_NAME) $(LOGFILE_PATH)

create: $(LOGFILE_PATH)/vivado_setup.log

open:
	vivado -mode gui -log $@ $(QCL_DESIGN_PRJECT)

sim: $(LOGFILE_PATH)/rtlsim.log

aws-hdk:
	cd $(BSG_F1_DIR)
	. $(AWS_FPGA_DIR)/hdk_setup.sh

synth: $(LOGFILE_PATH)/synth.log

clean:
	rm -rf vivado_*
	rm -rf open*
	rm -rf $(LOGFILE_PATH)/*.log
	rm -rf hs_err_pid*.log

bleach: clean
	rm -rf *_rom.v
	rm -rf $(VIVADO_PRJ_DIR)/$(QCL_DESIGN_NAME)

.PHONY: hardware testbench software remove_sw enet_trace_rom.v\
				create open sim synth \
				bleach

.DEFAULT_GOAL := help

help:
	@echo "Make"
	@echo "      hardware:  Prepare hardware source file of the design"
	@echo "      software:  Install the software for this design (sudo -E)"
	@echo "      create:    Create the Vivado project"
	@echo "      open:      Open an existing Vivado project"
	@echo	"      clean:     Clean non project stuff, software, testbench logs, etc."
	@echo "      bleach:    remove all project files"


