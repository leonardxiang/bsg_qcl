/*
*  bsg_fpga_board_pkg.v
*/

package bsg_fpga_board_pkg;

  parameter DEVICE_FAMILY = "virtexuplushbm";

  parameter axi_data_width_ddr_p = 512;
  parameter axi_addr_width_ddr_p = 64;
  parameter axi_id_width_ddr_p = 6;

  // data memory parameter
  localparam bram_data_width_lp = 256;

  localparam bram_size_p = bram_data_width_lp/8*8192;
  localparam bram_addr_width_p = `BSG_SAFE_CLOG2(bram_size_p);

  localparam hbm_size_p = 4*1024*1024*1024;
  localparam hbm_addr_width_p = `BSG_SAFE_CLOG2(hbm_size_p);

endpackage
