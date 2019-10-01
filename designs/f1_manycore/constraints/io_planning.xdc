# =====================================
# Add constraints
# =====================================
set_property PACKAGE_PIN BM29           [get_ports cpu_reset_i]
set_property IOSTANDARD  LVCMOS12       [get_ports cpu_reset_i]
set_false_path -from                    [get_ports cpu_reset_i]

set_property PACKAGE_PIN BH24           [get_ports led_o]
set_property IOSTANDARD  LVCMOS18       [get_ports led_o]
set_false_path -to                      [get_ports led_o]
