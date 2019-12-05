# Define config and filelists for project under the same folder

FPGA_PART = xcvu37p-fsvh2892-3-e-es1

include $(BSG_QCL_DIR)/environment.mk
# get configuration from bsg_f1 repo
# include $(BSG_F1_DIR)/environment.mk
# this replace the environment.mk to reduce the dependence
CL_DIR = $(BSG_F1_DIR)
HARDWARE_PATH = $(BSG_F1_DIR)/hardware
HARDWARE_PATH    := $(CL_DIR)/hardware
REGRESSION_PATH  := $(CL_DIR)/regression
TESTBENCH_PATH   := $(CL_DIR)/testbenches
LIBRARIES_PATH   := $(CL_DIR)/libraries
BSG_MACHINE_PATH := $(HARDWARE_PATH)

$(info $(shell echo -e "$(ORANGE)BSG MAKE INFO: F1 repo dir is defined as:$(NC)"))

include $(HARDWARE_PATH)/hardware.mk
VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_sif_async_buffer.v

# Replace any xilinx(unsynthesizable or F1 specific)
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v,$(VSOURCES))
VSOURCES += $(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v

VSOURCES := $(filter-out $(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_cache_to_axi_hashed.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_rx.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_rx.v,$(VSOURCES))

# Project defines
VHEADERS := $(BSG_QCL_DIR)/hdl/bsg_bladerunner_defines.vh $(VHEADERS)

# Filter out not used F1 headers
VHEADERS := $(filter-out ${BSG_F1_DIR}/hardware/cl_id_defines.vh,$(VHEADERS))
# VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/cl_manycore.sv,$(VHEADERS) $(VSOURCES))

# include folder path with vheads of this repo
VINCLUDES += $(BSG_QCL_DIR)/hdl
VINCLUDES += ${BSG_F1_DIR}/hardware

VSOURCES += $(BSG_QCL_DIR)/hdl/bsg_fpga_board_pkg.v
VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/s_axil_mcl_adapter.v,$(VHEADERS) $(VSOURCES))
VSOURCES += $(BSG_QCL_DIR)/hdl/s_axil_mcl_adapter.v

VSOURCES += $(BSG_QCL_DIR)/hdl/xilinx_ip/axi_register_slice.v
VSOURCES += $(BSG_QCL_DIR)/hdl/xilinx_ip/axi_register_slice_light.v
VSOURCES += $(BSG_QCL_DIR)/hdl/xilinx_ip/axi_register_slice_light.v
VSOURCES += $(BSG_QCL_DIR)/hdl/xilinx_ip/xilinx_dma_pcie_ep.v
VSOURCES += $(BSG_QCL_DIR)/hdl/lib_pip.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_debounce.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_counter_dynamic_limit_en.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_breath_en.v

# TODO: CHECK if this is necessary
bladerunner_setup:
	$(MAKE) -C $(BSG_BLADERUNNER_DIR) setup-uw

hardware:
	$(MAKE) -C ${HARDWARE_PATH} hardware