# Define config and filelists for project under the same folder

FPGA_PART = xcvu37p-fsvh2892-3-e-es1

# get configuration from bsg_f1 repo
# include $(BSG_F1_DIR)/environment.mk
CL_DIR = $(BSG_F1_DIR)
HARDWARE_PATH = $(BSG_F1_DIR)/hardware
include $(HARDWARE_PATH)/hardware.mk


# Replace F1 source include folder path with vheads of this repo
VINCLUDES += $(BSG_QCL_DIR)/hdl


# Replace F1 headerfile with vheads of this repo
# VHEADERS := $(filter-out ${BSG_F1_DIR}/hardware/bsg_axi_bus_pkg.vh,$(VHEADERS) $(VSOURCES))
VHEADERS += $(BSG_QCL_DIR)/hdl/bsg_bladerunner_defines.vh
VHEADERS += $(BSG_QCL_DIR)/hdl/bsg_axi4_bus_pkg.vh
VHEADERS := $(filter-out ${BSG_F1_DIR}/hardware/cl_id_defines.vh,$(VHEADERS) $(VSOURCES))


# Replace any xilinx(unsynthesizable or F1 specific) sources with xilinx-synthesizable sources
VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/cl_manycore.sv,$(VHEADERS) $(VSOURCES))
# VSOURCES += $(BSG_QCL_DIR)/designs/$(DESIGN_NAME)/$(DESIGN_NAME)_top.v, this is done in create_project.tcl

VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v,$(VHEADERS) $(VSOURCES))
VSOURCES += $(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v

VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/cl_manycore_pkg.v,$(VHEADERS) $(VSOURCES))
VSOURCES += $(BSG_QCL_DIR)/hdl/bsg_bladerunner_pkg.v

VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/s_axil_mcl_adapter.v,$(VHEADERS) $(VSOURCES))
VSOURCES += $(BSG_QCL_DIR)/hdl/s_axil_mcl_adapter.v

VSOURCES += $(BSG_QCL_DIR)/hdl/xilinx_dma_pcie_ep.v
VSOURCES += $(BSG_QCL_DIR)/hdl/bsg_bladerunner_wrapper.v
VSOURCES += $(BSG_QCL_DIR)/hdl/lib_pip.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_debounce.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_counter_dynamic_limit_en.v
VSOURCES += $(BSG_QCL_DIR)/hdl/qcl_breath_en.v
VSOURCES += $(BSG_QCL_DIR)/hdl/axi4_mux.v
VSOURCES += $(BSG_QCL_DIR)/hdl/axi_register_slice.v
VSOURCES += $(BSG_QCL_DIR)/hdl/axi_register_slice_light.v
VSOURCES += $(BSG_QCL_DIR)/hdl/axi_register_slice_light.v

# TODO: CHECK if this is necessary
bladerunner_setup:
	$(MAKE) -C $(BSG_BLADERUNNER_DIR) setup-uw

hardware:
	$(MAKE) -C ${HARDWARE_PATH} hardware