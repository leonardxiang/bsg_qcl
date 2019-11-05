/*
*  bsg_fpga_board_pkg.v
*/
`ifndef BSG_FPGA_BOARD_PKG_V
`define BSG_FPGA_BOARD_PKG_V

package bsg_fpga_board_pkg;


  // data memory parameter
  localparam bram_data_width_lp = 256;

  localparam bram_size_p = bram_data_width_lp/8*8192;
  localparam bram_addr_width_p = `BSG_SAFE_CLOG2(bram_size_p);

  localparam hbm_size_p = 4*1024*1024*1024;
  localparam hbm_addr_width_p = `BSG_SAFE_CLOG2(hbm_size_p);

endpackage

`endif
