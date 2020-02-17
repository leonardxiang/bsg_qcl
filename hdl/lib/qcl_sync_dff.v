/*
* qcl_sync_dff.v
*
*/

module qcl_sync_dff #(
  parameter width_p = 'X
  , parameter i_stages_p = 1
  , parameter o_stages_p = 1
) (
  input                clk_src_i
  ,input                clk_dst_i
  ,input  [width_p-1:0] src_d_i
  ,output [width_p-1:0] dst_d_o
);

  logic [width_p-1:0] sync_reg;

  qcl_pipe #(
    .width_p (width_p   ),
    .stages_p(i_stages_p)
  ) pip_i (
    .clk_i  (clk_src_i),
    .reset_i(1'b0     ),
    .d_i    (src_d_i  ),
    .d_o    (sync_reg )
  );

  qcl_pipe #(
    .width_p (width_p   ),
    .stages_p(o_stages_p)
  ) pip_o (
    .clk_i  (clk_dst_i),
    .reset_i(1'b0     ),
    .d_i    (sync_reg ),
    .d_o    (dst_d_o  )
  );

endmodule
