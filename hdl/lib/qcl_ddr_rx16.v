/*
* qcl_ddr_rx16.v
*
* wraps the xilinx iserdese ip
*
*/

module qcl_ddr_rx16 (
  input         clk_i
  ,input         reset_i
  ,input  [15:0] data_ser_p_i
  ,input  [15:0] data_ser_n_i
  ,output [31:0] data_par_o
);

  logic reset_li;

  qcl_domino #(.els_p(2), .val_p(1)) sync_rst (.clk_i(clk_i), .i(reset_i), .o(reset_li));

  // Instantiate the IO design
  iddr_16_lvds25 ddr16 (
    // From the system into the device
    .data_in_from_pins_p(data_ser_p_i),
    .data_in_from_pins_n(data_ser_n_i),
    .data_in_to_device  (data_par_o  ),
    .clk_in             (clk_i       ),
    .io_reset           (reset_li    )
  );

endmodule
