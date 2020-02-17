ORANGE=\033[0;33m
RED=\033[0;31m
NC=\033[0m

# set the QCL_REPO_DIR to current git repo if not defined in system environment
ifeq ("$(QCL_REPO_DIR)","")
QCL_REPO_DIR        := $(shell git rev-parse --show-toplevel)
endif

QCL_DESIGN_PATH    	:= $(QCL_REPO_DIR)/designs
QCL_HDL_PATH  	    := $(QCL_REPO_DIR)/hdl
QCL_DRIVER_PATH   	:= $(QCL_REPO_DIR)/drivers
QCL_RUNTIME_PATH   	:= $(QCL_REPO_DIR)/runtime
VIVADO_PRJ_DIR 			:= $(QCL_REPO_DIR)/vivado_prj

# Copy from bsg_f1/cadenv.mk
# You Should Have cloned bsg_bladerunner recursively, set BSG_BLADERUNNER_DIR
#
# Cosimulation requires VCS-MX and Vivado. Bespoke Silicon Group uses
# bsg_cadenv to reduce environment mis-configuration errors. We simply
# check to see if bsg_cadenv exists, and use cadenv.mk to configure
# EDA Environment if it is present. If it is not present, we check for
# Vivado and VCS and warn if they do not exist.
ifneq ("$(wildcard $(BSG_BLADERUNNER_DIR)/bsg_cadenv/cadenv.mk)","")
$(warning $(shell echo -e "$(ORANGE)BSG MAKE WARN: Found bsg_cadenv. Including cadenv.mk to configure cad environment.$(NC)"))
include $(BSG_BLADERUNNER_DIR)/bsg_cadenv/cadenv.mk
# We use vcs-mx, so we re-define VCS_HOME in the environment
export VCS_HOME=$(VCSMX_HOME)

#else ifndef VCS_HOME
#$(error $(shell echo -e "$(RED)BSG MAKE ERROR: VCS_HOME environment variable undefined. Are you sure vcs-mx is installed?$(NC)"))

endif

# XILINX_VIVADO is set by Vivado's configuration script. We use this
# as a quick check instead of running Vivado.
ifndef XILINX_VIVADO
$(error $(shell echo -e "$(RED)BSG MAKE ERROR: XILINX_VIVADO environment variable undefined. Are you sure Vivado is installed?$(NC)"))
endif

