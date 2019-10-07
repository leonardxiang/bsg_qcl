# =====================================
# Add vivado ip source files
# =====================================
set VIVADO_IP_DIR $env(XILINX_VIVADO_DIR)/data/ip/xilinx
add_files -fileset sources_1 -norecurse [join "
${VIVADO_IP_DIR}/axi_infrastructure_v1_1/hdl/axi_infrastructure_v1_1_0.vh
${VIVADO_IP_DIR}/axi_infrastructure_v1_1/hdl/axi_infrastructure_v1_1_vl_rfs.v
${VIVADO_IP_DIR}/axi_register_slice_v2_1/hdl/axi_register_slice_v2_1_vl_rfs.v
${VIVADO_IP_DIR}/generic_baseblocks_v2_1/hdl/generic_baseblocks_v2_1_vl_rfs.v
${VIVADO_IP_DIR}/axi_crossbar_v2_1/hdl/axi_crossbar_v2_1_vl_rfs.v

${VIVADO_IP_DIR}/axis_infrastructure_v1_1/hdl/axis_infrastructure_v1_1_0.vh
${VIVADO_IP_DIR}/axis_infrastructure_v1_1/hdl/axis_infrastructure_v1_1_vl_rfs.v
${VIVADO_IP_DIR}/axis_register_slice_v1_1/hdl/axis_register_slice_v1_1_vl_rfs.v
${VIVADO_IP_DIR}/axis_dwidth_converter_v1_1/hdl/axis_dwidth_converter_v1_1_vl_rfs.v
"]


# =====================================
# generate ips
# =====================================
set PRJ_IP_DIR ${DESIGN_PRJ_DIR}/${DESIGN_NAME}.srcs/sources_1/ip

# -------------------------------------
# axi data width converter
# -------------------------------------
create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip \
  -version 2.1 -module_name axi_dwidth_converter_0
set_property -dict [list \
CONFIG.ADDR_WIDTH {64} \
CONFIG.SI_DATA_WIDTH {64} \
CONFIG.MI_DATA_WIDTH {256} \
CONFIG.SI_ID_WIDTH {4} \
CONFIG.MAX_SPLIT_BEATS {16} \
CONFIG.FIFO_MODE {1}
] [get_ips axi_dwidth_converter_0]
generate_target {instantiation_template} [get_files ${PRJ_IP_DIR}/axi_dwidth_converter_0/axi_dwidth_converter_0.xci]
set_property generate_synth_checkpoint false [get_files  ${PRJ_IP_DIR}/axi_dwidth_converter_0/axi_dwidth_converter_0.xci]
generate_target all [get_files  ${PRJ_IP_DIR}/axi_dwidth_converter_0/axi_dwidth_converter_0.xci]

# -------------------------------------
# axi bram
# -------------------------------------
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip \
  -version 4.0 -module_name axi_bram_ctrl_0
set_property -dict [list \
CONFIG.DATA_WIDTH {256} \
CONFIG.ID_WIDTH {6} \
CONFIG.SUPPORTS_NARROW_BURST {0} \
CONFIG.SINGLE_PORT_BRAM {1} \
CONFIG.ECC_TYPE {0} \
CONFIG.BMG_INSTANCE {INTERNAL}
] [get_ips axi_bram_ctrl_0]
generate_target {instantiation_template} [get_files ${PRJ_IP_DIR}/axi_bram_ctrl_0/axi_bram_ctrl_0.xci]
set_property generate_synth_checkpoint false [get_files  ${PRJ_IP_DIR}/axi_bram_ctrl_0/axi_bram_ctrl_0.xci]
generate_target all [get_files  ${PRJ_IP_DIR}/axi_bram_ctrl_0/axi_bram_ctrl_0.xci]


# -------------------------------------
# block memory
# -------------------------------------
create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
  -version 8.4 -module_name blk_mem_gen_1
set_property -dict [list \
CONFIG.Component_Name {blk_mem_gen_1} \
CONFIG.Interface_Type {AXI4} \
CONFIG.Use_AXI_ID {true} \
CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
CONFIG.Use_Byte_Write_Enable {true} \
CONFIG.Byte_Size {8} \
CONFIG.Assume_Synchronous_Clk {true} \
CONFIG.Write_Width_A {64} \
CONFIG.Write_Depth_A {512} \
CONFIG.Read_Width_A {64} \
CONFIG.Operating_Mode_A {READ_FIRST} \
CONFIG.Write_Width_B {64} \
CONFIG.Read_Width_B {64} \
CONFIG.Operating_Mode_B {READ_FIRST} \
CONFIG.Enable_B {Use_ENB_Pin} \
CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
CONFIG.Use_RSTB_Pin {true} \
CONFIG.Reset_Type {ASYNC} \
CONFIG.Port_B_Clock {100} \
CONFIG.Port_B_Enable_Rate {100} \
CONFIG.EN_SAFETY_CKT {true}
] [get_ips blk_mem_gen_1]
generate_target {instantiation_template} [get_files ${PRJ_IP_DIR}/blk_mem_gen_1/blk_mem_gen_1.xci]
set_property generate_synth_checkpoint false [get_files  ${PRJ_IP_DIR}/blk_mem_gen_1/blk_mem_gen_1.xci]
generate_target all [get_files  ${PRJ_IP_DIR}/blk_mem_gen_1/blk_mem_gen_1.xci]


# -------------------------------------
# axi stream fifo
# -------------------------------------
create_ip -name axi_fifo_mm_s -vendor xilinx.com -library ip \
  -version 4.1 -module_name axi_fifo_mm_s_0

set_property -dict [list \
CONFIG.C_TX_FIFO_PE_THRESHOLD {5} \
CONFIG.C_RX_FIFO_PE_THRESHOLD {5}
] [get_ips axi_fifo_mm_s_0]
generate_target {instantiation_template} [get_files ${PRJ_IP_DIR}/axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci]
set_property generate_synth_checkpoint false [get_files ${PRJ_IP_DIR}/axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci]
generate_target all [get_files  ${PRJ_IP_DIR}/axi_fifo_mm_s_0/axi_fifo_mm_s_0.xci]


# -------------------------------------
# pcie subsystem
# -------------------------------------
create_ip -name xdma -vendor xilinx.com -library ip \
  -version 4.1 -module_name xdma_0
set_property -dict [list \
CONFIG.pcie_blk_locn {PCIE4C_X1Y0} \
CONFIG.pl_link_cap_max_link_width {X4} \
CONFIG.axisten_freq {125} \
CONFIG.pf0_device_id {9014} \
CONFIG.axilite_master_en {true} \
CONFIG.axist_bypass_en {true} \
CONFIG.select_quad {GTY_Quad_227} \
CONFIG.pf0_msix_cap_table_bir {BAR_1} \
CONFIG.pf0_msix_cap_pba_bir {BAR_1} \
CONFIG.PF0_DEVICE_ID_mqdma {9014} \
CONFIG.PF2_DEVICE_ID_mqdma {9014} \
CONFIG.PF3_DEVICE_ID_mqdma {9014}
] [get_ips xdma_0]
generate_target {instantiation_template} [get_files ${PRJ_IP_DIR}/xdma_0/xdma_0.xci]
set_property generate_synth_checkpoint false [get_files ${PRJ_IP_DIR}/xdma_0/xdma_0.xci]
generate_target all [get_files ${PRJ_IP_DIR}/xdma_0/xdma_0.xci]


# =====================================
# add constraints
# =====================================
set DESIGN_CONSTRAINT_DIR ./${DESIGN_NAME}/constraints
add_files -fileset constrs_1 ${DESIGN_CONSTRAINT_DIR}/xdma.xdc
add_files -fileset constrs_1 ${DESIGN_CONSTRAINT_DIR}/io_planning.xdc
add_files -fileset constrs_1 ${DESIGN_CONSTRAINT_DIR}/configuration.xdc
add_files -fileset constrs_1 ${DESIGN_CONSTRAINT_DIR}/debug_core.xdc
set_property target_constrs_file ${DESIGN_CONSTRAINT_DIR}/debug_core.xdc [current_fileset -constrset]
