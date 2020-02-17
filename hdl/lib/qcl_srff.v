/*
* qcl_srff.v
*
*/

module qcl_srff #(
  parameter width_p = 1
  ,parameter set_val_p = {width_p{1'b1}}
  ,parameter reset_val_p = 0
) (
  input                clk_i
  ,input                set_i
  ,input                reset_i
  ,output [width_p-1:0] data_o
);

`ifdef FPGA_LESS_RST
  logic [width_p-1:0] data_r = width_p'(reset_val_p);
`else
  logic [width_p-1:0] data_r;
`endif

  assign data_o = data_r;

  always_ff @(posedge clk_i) begin
    if (set_i)
      data_r <= width_p'(set_val_p);
    else if (reset_i)
      data_r <= width_p'(reset_val_p);
  end

  // synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (set_i & reset_i)
      $fatal(0, "## [%m] set and reset cannot be asserted at the same time!\n",,,$time());
  end
  // synopsys translate_on

endmodule
