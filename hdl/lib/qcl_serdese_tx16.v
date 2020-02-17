/*
* qcl_serdese_tx16.v
*
* wraps the mmcm to generate 500Mhz clock for lvds oserdese
*
*/

module qcl_serdese_tx16 (
  input         clk_lvds_i
  ,input         clk_div_i
  ,input         reset_i
  ,input  [63:0] data_par_i
  ,output [15:0] data_ser_p_o
  ,output [15:0] data_ser_n_o
  ,output        clk_fwd_p_o
  ,output        clk_fwd_n_o
);

  // https://www.xilinx.com/support/documentation/user_guides/ug471_7Series_SelectIO.pdf
  // OSERDESE2:
  // Reset Input - RSTWhen asserted, the reset input causes the outputs of all data flip-flops in the CLK and CLKDIV
  // domains to be driven low asynchronously. When deasserted synchronously with CLKDIV, internal logic re-times this
  // deassertion to the first rising edge of CLK. Every OSERDESE2 in a multiple bit output structure should therefore be
  // driven by the same reset signal, asserted asynchronously, and deasserted synchronously to CLKDIV to ensure that all
  // OSERDESE2 elements come out of reset in synchronization. The reset signal should only be deasserted when it is known
  // that CLK and CLKDIV are stable and present

  logic reset_li;

  qcl_domino #(.els_p(8), .val_p(1)) dmo_sync_rst (.clk_i(clk_div_i), .i(reset_i), .o(reset_li));

if (`FPGA_ARCH == "XILINX_7SERIES") begin
  oserdese2_4x16_lvds25 serdese_4x16 (
    .data_out_from_device(data_par_i  ),
    .data_out_to_pins_p  (data_ser_p_o),
    .data_out_to_pins_n  (data_ser_n_o),
    .clk_to_pins_p       (clk_fwd_p_o ),
    .clk_to_pins_n       (clk_fwd_n_o ),
    .clk_in              (clk_lvds_i  ),
    .clk_div_in          (clk_div_i   ),
    .clk_reset           (reset_i     ), // not used though
    .io_reset            (reset_li    )  // requirement see above
  );
end
else begin
  assign data_ser_p_o = '0;
  assign data_ser_n_o = ~data_ser_p_o;
  assign clk_fwd_p_o = '0;
  assign clk_fwd_n_o = ~clk_fwd_p_o;
end

endmodule
