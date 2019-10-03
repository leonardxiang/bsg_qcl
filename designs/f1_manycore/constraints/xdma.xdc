##-----------------------------------------------------------------------------
##
## (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##-----------------------------------------------------------------------------
##
## Project    : The Xilinx PCI Express DMA
## File       : xilinx_xdma_pcie_x1y0.xdc
## Version    : 4.1
##-----------------------------------------------------------------------------
#
# User Configuration
# Link Width   - x2
# Link Speed   - Gen1
# Family       - virtexuplusHBM
# Part         - xcvu37p
# Package      - fsvh2892
# Speed grade  - -3
###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################
##
## Free Running Clock is Required for IBERT/DRP operations.
##
###############################################################################
create_clock -name sys_clk -period 10 [get_ports sys_clk_i_p]
#
###############################################################################
set_false_path -from [get_ports sys_resetn_i]
set_property PULLUP true [get_ports sys_resetn_i]
set_property IOSTANDARD LVCMOS18 [get_ports sys_resetn_i]
set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports sys_resetn_i]
#set_property PACKAGE_PIN AJ31 [get_ports sys_resetn_i]
#
set_property CONFIG_VOLTAGE 1.8 [current_design]
#
###############################################################################
set_property LOC [get_package_pins \
  -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} \
    -of_objects [get_iobanks \
      -of_objects [get_sites GTYE4_CHANNEL_X1Y15]]]/REFCLK0P]] \
  [get_ports sys_clk_i_p]
set_property LOC [get_package_pins \
  -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} \
    -of_objects [get_iobanks \
      -of_objects [get_sites GTYE4_CHANNEL_X1Y15]]]/REFCLK0N]] \
  [get_ports sys_clk_i_n]
#
###############################################################################

###############################################################################
#

#
# BITFILE/BITSTREAM compress options
#
#set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-1 [current_design]
#set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type1 [current_design]
#set_property CONFIG_MODE BPI16 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]
#
#
set_false_path -to [get_pins -hier *sync_reg[0]/D]
#


##-----------------------------------------------------------------------------
##
## Project    : UltraScale+ FPGA PCI Express CCIX v4.0 Integrated Block
## File       : xdma_0_pcie4c_ip_late.xdc
## Version    : 1.0 
##-----------------------------------------------------------------------------
#
# This constraints file contains ASYNC clock grouping and processed late after OOC and IP Level XDC files. 
#
#
###############################################################################
# ASYNC CLOCK GROUPINGS
###############################################################################
# sys_clk vs TXOUTCLK
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_ports sys_clk*]] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *gen_channel_container[*].*gen_gtye4_channel_inst[*].GTYE4_CHANNEL_PRIM_INST/TXOUTCLK}]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *gen_channel_container[*].*gen_gtye4_channel_inst[*].GTYE4_CHANNEL_PRIM_INST/TXOUTCLK}]] -group [get_clocks -of_objects [get_ports sys_clk*]]
#
# sys_clk vs intclk
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O]] -group [get_clocks -of_objects [get_ports sys_clk*]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_ports sys_clk*]] -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O]]
#
# intclk vs pclk
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O]] -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_pclk/O]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_pclk/O]] -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O]]
#
# sys_clk vs pclk
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_ports sys_clk*]] -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_pclk/O]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_pclk/O]] -group [get_clocks -of_objects [get_ports sys_clk*]]
#
