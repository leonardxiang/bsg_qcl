# Define config and filelists for project under the same folder

FPGA_PART ?= xcvu37p-fsvh2892-3-e-es1

$(QCL_DESIGN_NAME) ?= hbm_manycore

ifndef BSG_MACHINE_PATH
PROJECT = $(QCL_DESIGN_NAME)
CL_DIR           := $(BSG_F1_DIR)
HARDWARE_PATH    := $(CL_DIR)/hardware
REGRESSION_PATH  := $(CL_DIR)/regression
TESTBENCH_PATH   := $(CL_DIR)/testbenches
LIBRARIES_PATH   := $(CL_DIR)/libraries
BSG_MACHINE_PATH := $(CL_DIR)/machines/$(QCL_DESIGN_NAME)
hardware:
	$(MAKE) -C $(BSG_F1_DIR)/hardware hardware
	$(info $(shell echo -e "$(ORANGE)==================================$(NC)"))
	$(info $(shell echo -e "$(ORANGE)== Adding Bladerunner Filelist! ==$(NC)"))
	$(info $(shell echo -e "$(ORANGE)==================================$(NC)"))
include $(BSG_F1_DIR)/hardware/hardware.mk
else
$(info $(shell echo -e "$(ORANGE)===================================$(NC)"))
$(info $(shell echo -e "$(ORANGE)= Modifying Bladerunner Filelist! =$(NC)"))
$(info $(shell echo -e "$(ORANGE)===================================$(NC)"))
endif

# include folder path with vheads of this repo
# VINCLUDES += ${BSG_F1_DIR}/hardware
# VINCLUDES := $(filter-out $(HARDWARE_PATH),$(VINCLUDES))
VINCLUDES += $(QCL_HDL_PATH)/bladerunner_replace

# Replace any xilinx(unsynthesizable or F1 specific)
VHEADERS := $(filter-out ${BSG_F1_DIR}/hardware/cl_id_defines.vh,$(VHEADERS))
VHEADERS := $(filter-out ${BSG_F1_DIR}/hardware/bsg_axi_bus_pkg.vh,$(VHEADERS))
VHEADERS += $(QCL_HDL_PATH)/bladerunner_replace/bsg_axi_bus_pkg.vh
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v,$(VSOURCES))
VSOURCES += $(BASEJUMP_STL_DIR)/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v

VHEADERS += $(QCL_DESIGN_PATH)/$(QCL_DESIGN_NAME)/bsg_fpga_board_pkg.v
VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/cl_manycore.sv,$(VSOURCES))

ifdef SYNTH_MODE
VHEADERS += $(QCL_DESIGN_PATH)/$(QCL_DESIGN_NAME)/$(QCL_DESIGN_NAME).vh
VSOURCES += $(QCL_DESIGN_PATH)/$(QCL_DESIGN_NAME)/$(QCL_DESIGN_NAME)_top.v
VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/xilinx_dma_pcie_ep.v
# VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/axi_wrapper/axi_register_slice.v
VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/axi_wrapper/axi_register_slice_light.v
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_decode.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_dma.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_miss.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_sbuf_queue.v,$(VSOURCES))

# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_decode.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_miss_fifo.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_data_mem.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_stat_mem.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_tag_mem.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_dma.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_mhu.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_non_blocking_tl_stage.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_to_cache_non_blocking.v,$(VSOURCES))
# VSOURCES := $(filter-out $(BSG_MANYCORE_DIR)/v/bsg_manycore_vcache_non_blocking.v,$(VSOURCES))

VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_dmc/bsg_dmc_pkg.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_dmc/bsg_dmc.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_dmc/bsg_dmc_controller.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_dmc/bsg_dmc_phy.v,$(VSOURCES))
else
VSOURCES += $(QCL_DESIGN_PATH)/$(QCL_DESIGN_NAME)/cl_manycore.sv
endif

# VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/cl_manycore_pkg.v,$(VSOURCES))
# VSOURCES += $(QCL_HDL_PATH)/bladerunner_replace/cl_manycore_pkg.v

# VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/bsg_bladerunner_mem_cfg_pkg.v,$(VSOURCES))
# VSOURCES += $(QCL_HDL_PATH)/bladerunner_replace/bsg_bladerunner_mem_cfg_pkg.v

VSOURCES := $(filter-out $(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_cache_to_axi_hashed.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_tx.v,$(VSOURCES))
VSOURCES := $(filter-out $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_rx.v,$(VSOURCES))
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi.v

# VSOURCES += $(BSG_MANYCORE_DIR)/v/bsg_manycore_link_sif_async_buffer.v

VSOURCES += $(QCL_HDL_PATH)/bladerunner_replace/lib_pip.v
VSOURCES += $(QCL_HDL_PATH)/bladerunner_replace/bladerunner_wrapper.v
VSOURCES += $(QCL_HDL_PATH)/bladerunner_replace/manycore_memory_hierarchy.v
VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/axi_wrapper/axi4_clock_converter.v
VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/axi_wrapper/axi4_mux.v
VSOURCES += $(QCL_HDL_PATH)/xilinx_ip/axi_wrapper/axi4_data_width_converter.v

# VSOURCES := $(filter-out ${BSG_F1_DIR}/hardware/s_axil_mcl_adapter.v,$(VHEADERS) $(VSOURCES))
# VSOURCES += $(QCL_HDL_PATH)/s_axil_mcl_adapter.v

VSOURCES += $(QCL_HDL_PATH)/lib/qcl_debounce.v
VSOURCES += $(QCL_HDL_PATH)/lib/qcl_counter_dynamic_limit_en.v
VSOURCES += $(QCL_HDL_PATH)/lib/qcl_breath_en.v
