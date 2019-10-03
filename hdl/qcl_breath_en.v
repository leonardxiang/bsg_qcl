/*
* qcl_breath_en.v
*
* count the event i to val_p, then flip the output
* the breach period is 1 / F_clk_i * val_p * 2
*/

`include "bsg_defines.v"

module qcl_breath_en #(parameter val_p = 'd10_000_000) (
  input  clk_i  
  ,input  reset_i
  ,input  en_i   
  ,output o
);

  localparam counter_width_lp = `BSG_SAFE_CLOG2(val_p+1); // use safe clog2 in case val_p=0

  logic overflow_lo;

  qcl_counter_dynamic_limit_en #(.width_p(counter_width_lp)) cnt_flop (
    .clk_i     (clk_i                     ),
    .reset_i   (reset_i | overflow_lo     ),
    .en_i      (en_i                      ),
    .limit_i   (counter_width_lp'(val_p+1)),
    .count_o   (                          ),
    .overflow_o(overflow_lo               )
  );


  logic o_r;
  always_ff @(posedge clk_i) begin
    if (reset_i)
      o_r <= '0;
    else if (overflow_lo)
      o_r <= ~o_r;
  end

  assign o = o_r;
  
endmodule
