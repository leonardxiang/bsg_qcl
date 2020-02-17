/*
* qcl_edge_detect.v
*
*/

module qcl_edge_detect #(
  parameter falling_not_rising_p = 0
  , parameter reset_val_p = 0
) (
  input  clk_i
  ,input  reset_i
  ,input  sig_i
  ,output detect_o
);

  logic sig_r;

  qcl_dff_reset #(.width_p(1), .reset_val_p(reset_val_p)) sig_reg (
    .clk_i  (clk_i  ),
    .reset_i(reset_i),
    .data_i (sig_i  ),
    .data_o (sig_r  )
  );

  if (falling_not_rising_p == 1)  begin : falling
    assign detect_o = ~sig_i & sig_r;
  end
  else begin : rising
    assign detect_o = sig_i & ~sig_r;
  end

endmodule
