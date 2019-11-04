# =====================================
# Add constraints
# =====================================
#create_clock -name sys_clk -period 10 [get_ports mem_clk_i_p]
set_property PACKAGE_PIN BH51 [get_ports mem_clk_i_p]
set_property PACKAGE_PIN BJ51 [get_ports mem_clk_i_n]
set_property IOSTANDARD  DIFF_SSTL12 [get_ports mem_clk_i_p] ;# Bank  66 VCCO - DDR4_VDDQ_1V2 - IO_L11N_T1U_N9_GC_66
set_property IOSTANDARD  DIFF_SSTL12 [get_ports mem_clk_i_n] ;# Bank  66 VCCO - DDR4_VDDQ_1V2 - IO_L11N_T1U_N9_GC_66

set_property PACKAGE_PIN BM29           [get_ports ext_btn_reset_i]
set_property IOSTANDARD  LVCMOS12       [get_ports ext_btn_reset_i]
set_false_path -from                    [get_ports ext_btn_reset_i]

set_property PACKAGE_PIN BH24           [get_ports leds_o[0]]
set_property PACKAGE_PIN BG24           [get_ports leds_o[1]]
set_property PACKAGE_PIN BG25           [get_ports leds_o[2]]
set_property PACKAGE_PIN BF25           [get_ports leds_o[3]]
set_property PACKAGE_PIN BF26           [get_ports leds_o[4]]
set_property PACKAGE_PIN BF27           [get_ports leds_o[5]]
set_property PACKAGE_PIN BG27           [get_ports leds_o[6]]
set_property PACKAGE_PIN BG28           [get_ports leds_o[7]]
set_property IOSTANDARD  LVCMOS18       [get_ports leds_o[*]]
set_false_path -to                      [get_ports leds_o[*]]
