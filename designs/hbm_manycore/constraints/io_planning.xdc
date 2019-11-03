# =====================================
# Add constraints
# =====================================
set_property PACKAGE_PIN BM29           [get_ports cpu_reset_i]
set_property IOSTANDARD  LVCMOS12       [get_ports cpu_reset_i]
set_false_path -from                    [get_ports cpu_reset_i]

set_property PACKAGE_PIN BH24           [get_ports led_o[0]]
set_property PACKAGE_PIN BG24           [get_ports led_o[1]]
set_property PACKAGE_PIN BG25           [get_ports led_o[2]]
set_property PACKAGE_PIN BF25           [get_ports led_o[3]]
set_property PACKAGE_PIN BF26           [get_ports led_o[4]]
set_property PACKAGE_PIN BF27           [get_ports led_o[5]]
set_property PACKAGE_PIN BG27           [get_ports led_o[6]]
set_property PACKAGE_PIN BG28           [get_ports led_o[7]]
set_property IOSTANDARD  LVCMOS18       [get_ports led_o[*]]
set_false_path -to                      [get_ports led_o[*]]
