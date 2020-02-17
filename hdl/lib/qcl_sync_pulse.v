/*
* qcl_sync_pulse.v
*
* cross clock domain for ppulse signals
*/

module qcl_sync_pulse #(
  parameter width_p = 1
  , parameter i_stages_p = 1
  , parameter o_stages_p = 1
  , parameter falling_not_rising_p = 0
) (
  input                clk_src_i
  ,input                clk_dst_i
  ,input  [width_p-1:0] src_i
  ,output [width_p-1:0] dst_o
);

  logic [width_p-1:0] src_li  ;
  logic [width_p-1:0] src_sync;
  logic [width_p-1:0] dst_sync;

  if (falling_not_rising_p)
    assign src_li = ~src_i;
  else
    assign src_li = src_i;

  for (genvar k = 0; k < width_p; k++) begin : stretch_src
    if (i_stages_p >= 2)
      qcl_domino #(
        .els_p(i_stages_p),
        .val_p(1         )
      ) dmo (
        .clk_i(clk_src_i  ),
        .i    (src_li[k]  ),
        .o    (src_sync[k])
      );
    else if(i_stages_p == 1)
      qcl_pipe pip_src (.clk_i(clk_src_i), .reset_i(1'b0), .d_i(src_li[k]), .d_o(src_sync[k]));
    else
      assign src_sync[k] = src_li[k];
  end

  qcl_pipe #(.width_p(width_p), .stages_p(o_stages_p)) pip_dst (
    .clk_i  (clk_dst_i),
    .reset_i(1'b0     ),
    .d_i    (src_sync ),
    .d_o    (dst_sync )
  );

  for (genvar k = 0; k < width_p; k++) begin : pedge_dst
    qcl_edge_detect #(.falling_not_rising_p(0)) pedge_dst (
      .clk_i   (clk_dst_i  ),
      .reset_i (1'b0       ),
      .sig_i   (dst_sync[k]),
      .detect_o(dst_o[k]   )
    );
  end : pedge_dst

endmodule
