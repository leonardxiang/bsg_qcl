/*
*  bsg_fpga_board_pkg.v
*/
`ifndef BSG_FPGA_BOARD_PKG_V
`define BSG_FPGA_BOARD_PKG_V

package bsg_fpga_board_pkg;

//  `include "cl_manycore_pkg.v"

  import cl_manycore_pkg::*;

  // data memory parameter
  parameter bram_size_p = axi_data_width_p*8192/8;
  parameter bram_addr_width_p = `BSG_SAFE_CLOG2(bram_size_p);

  parameter hbm_size_p = 4*1024*1024*1024;
  parameter hbm_addr_width_p = `BSG_SAFE_CLOG2(hbm_size_p);

endpackage

`endif
