# Define config and filelists for project under the same folder

FPGA_PART = xc7a200tfbg676-2
# FPGA_PART = xc7k325tffg900-2

hardware:
	$(MAKE) -C $(BSG_F1_DIR)/hardware hardware

VHEADERS += $(HARDWARE_PATH)/f1_parameters.vh
VSOURCES += $(HARDWARE_PATH)/cl_manycore_pkg.v
VSOURCES += $(HARDWARE_PATH)/bsg_bladerunner_mem_cfg_pkg.v

# get configuration from bsg repos
include $(BSG_MANYCORE_DIR)/machines/arch_filelist.mk

# Replace any xilinx(unsynthesizable or F1 specific)
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v,$(VSOURCES))
VSOURCES += $(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v

VSOURCES += $(QCL_DIR)/hdl/mc_memory_hierarchy.v
