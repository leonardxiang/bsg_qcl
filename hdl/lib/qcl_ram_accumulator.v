/*
* qcl_ram_accumulator.v
*
* accumulate the waveform and store to sram block
//           read                              write
//          |bram|  |dff_rst|     |adder|      |bram|       |update new address
// enable_i(on) => data_o => data_lo_1d-- + => data_sum_lo => data_o
//  clear  clear data_i => wave_se_r/

// Note: clear ends at the last enable_i
*/

module qcl_ram_accumulator #(
  parameter width_in_p = "inv"
  , parameter width_out_p = "inv"
  , parameter els_p = "inv"
  , localparam addr_width_lp = $clog2(els_p)
) (
  input                      clk_i
  ,input                      init_i
  ,input                      clear_i
  ,input                      enable_i
  ,input  [$clog2(els_p)-1:0] acc_addr_i
  ,input  [   width_in_p-1:0] data_i
  ,input                      r_v_i
  ,input  [addr_width_lp-1:0] r_addr_i
  ,output [  width_out_p-1:0] r_data_o
  ,output                     overflow_o
);

  logic clear_1d;
  qcl_pipe #(
    .width_p (1),
    .stages_p(1)
  ) pip_clear (
    .clk_i  (clk_i   ),
    .reset_i(1'b0    ),
    .d_i    (clear_i ),
    .d_o    (clear_1d)
  );

  wire [addr_width_lp-1:0] r_w_addr_li = enable_i ? acc_addr_i : r_addr_i;

  logic                     rw_v_3d   ;
  logic [addr_width_lp-1:0] rw_addr_3d;

  qcl_pipe #(.width_p(1), .stages_p(3)) pip_w_valid (
    .clk_i  (clk_i   ),
    .reset_i(1'b0    ),
    .d_i    (enable_i),
    .d_o    (rw_v_3d )
  );
  qcl_pipe #(.width_p(addr_width_lp), .stages_p(3)) pip_w_addr (
    .clk_i  (clk_i     ),
    .reset_i(1'b0      ),
    .d_i    (acc_addr_i),
    .d_o    (rw_addr_3d)
  );


  // stage 1
  //
  logic [width_out_p-1:0] data_se_lo;

  wire [width_out_p-1:0] data_se_li = {{(width_out_p-width_in_p){data_i[width_in_p-1]}},data_i};

  bsg_dff #(.width_p(width_out_p)) dff_data (.clk_i,.data_i(data_se_li), .data_o(data_se_lo));


  // stage 2
  logic [width_out_p-1:0] data_lo_1d, data_sum_lo;
  logic overflow_lo;

  // wait for the reading ram data
  qcl_dff_reset #(.width_p(width_out_p)) dff_rst_rdata (
    .clk_i  (clk_i     ),
    .reset_i(clear_1d  ),
    .data_i (r_data_o  ),
    .data_o (data_lo_1d)  // + 2 to enable_i
  );

  qcl_add_sub #(
    .width_p         (width_out_p),
    .latency_p       (1          ),
    .harden_p        (1          ),
    .is_add_not_sub_p(1'b1       )
  ) add_wave (
    .clk_i  (clk_i      ),
    .reset_i(1'b0       ),
    .a_i    (data_lo_1d ),
    .b_i    (data_se_lo ),
    .s_o    (data_sum_lo),
    .c_o    (overflow_lo)
  );


  // stage 3
  //
  qcl_bram_sdp_1clk_1r1w #(
    .width_p(width_out_p),
    .els_p  (els_p      )
  ) bram_accum (
    .clk_i   (clk_i         ),
    .w_v_i   (rw_v_3d       ),
    .w_addr_i(rw_addr_3d    ),
    .w_data_i(data_sum_lo   ),
    .r_v_i   (enable_i|r_v_i),
    .r_addr_i(r_w_addr_li   ),
    .r_data_o(r_data_o      )  // + 1 to enable_i
  );

  bsg_dff_reset_en #(.width_p(1), .reset_val_p(0)) dff_ovrange (
    .clk_i  (clk_i      ),
    .reset_i(clear_i    ),
    .en_i   (overflow_lo),
    .data_i (1'b1       ),
    .data_o (overflow_o )
  );

endmodule
