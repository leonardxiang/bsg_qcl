/*
* qcl_accumulator.v
*
* latency = 1
*/

module qcl_accumulator #(
  parameter width_p = "inv"
  , parameter harden_p = 0
) (
  input clk_i
  , input reset_i
  , input v_i
  , input [width_p-1:0] data_i
  , output [width_p-1:0] sum_o
  , output v_o
);

  logic [width_p-1:0] sum_r;

  qcl_add_sub #(
    .width_p         (width_p ),
    .latency_p       (0       ),
    .harden_p        (harden_p),
    .is_add_not_sub_p(1'b1    )
  ) add_wave (
    .clk_i  (clk_i ),
    .reset_i(1'b0  ),
    .a_i    (data_i),
    .b_i    (sum_o ),
    .s_o    (sum_r ),
    .c_o    (      )
  );

  bsg_dff_reset_en #(.width_p(width_p)) dff_data (
    .clk_i  (clk_i   ),
    .reset_i(reset_i),
    .en_i   (v_i    ),
    .data_i (sum_r  ),
    .data_o (sum_o  )
  );

  qcl_pipe pip_v (.clk_i(clk_i), .reset_i(1'b0), .d_i(v_i), .d_o(v_o));

endmodule
