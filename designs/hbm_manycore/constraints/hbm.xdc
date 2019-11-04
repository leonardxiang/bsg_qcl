

# create_clock -period 10 [get_ports APB_0_PCLK]

# create_clock -period 10.000 [get_ports AXI_ACLK_IN_0]
set_property LOC MMCM_X0Y0 [get_cells -hier -filter {NAME =~ u_mmcm_0}]


set_property IOSTANDARD LVCMOS12 [get_ports APB_0_PCLK]
set_property IOSTANDARD LVCMOS12 [get_ports APB_0_PRESET_N]
set_property IOSTANDARD LVCMOS12 [get_ports AXI_ACLK_IN_0]
set_property IOSTANDARD LVCMOS12 [get_ports AXI_ARESET_N_0]
set_property IOSTANDARD LVCMOS12 [get_ports axi_trans_err]

create_pblock pblock_1

      resize_pblock pblock_1 -add {SLICE_X0Y0:SLICE_X116Y121 DSP48E2_X0Y0:DSP48E2_X15Y41 RAMB18_X0Y0:RAMB18_X7Y47 RAMB36_X0Y0:RAMB36_X7Y23 URAM288_X0Y0:URAM288_X1Y31}
add_cells_to_pblock pblock_1 -top






create_waiver -internal -type CDC -id CDC-1 -description "This is a safe CDC in this design per review with team" -from [get_pins *.u_atg_vio_*/inst/DECODER_INST/Hold_probe_in_reg/C] -to [get_pins *.u_atg_vio_*/inst/PROBE_IN_INST/probe_in_reg_reg[*]/CE]
create_waiver -internal -type CDC -id CDC-4 -description "This is a safe CDC in this design per review with team" -from [get_pins *.u_atg_vio_*/inst/PROBE_IN_INST/probe_in_reg_reg[*]/C] -to [get_pins *.u_atg_vio_*/inst/PROBE_IN_INST/data_int_sync1_reg[*]/D]

set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets */*APB_0_PCLK]
