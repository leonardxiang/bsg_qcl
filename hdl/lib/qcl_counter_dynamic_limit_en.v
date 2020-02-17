/*
* qcl_counter_dynamic_limit_en.v
*
* simple counter with enable signal and dynamic upper limit
* counter outputs [0:limit)
* module renamed from bsg_counter_dynamic_limit_en.v
*/

module qcl_counter_dynamic_limit_en #(parameter width_p = "inv") (
  input                clk_i
  ,input                reset_i
  ,input                en_i
  ,input  [width_p-1:0] limit_i
  ,output [width_p-1:0] count_o
  ,output               overflow_o
);

  logic [width_p-1:0] count_r;

  wire [width_p-1:0] count_pls_1 = count_r + width_p'(1);

  always_ff @ (posedge clk_i) begin
    if (reset_i)
      count_r <= '0;
    else
      if (en_i) begin
        if(overflow_o)
          count_r <= '0;
        else
          count_r <= count_pls_1;
      end
  end

  assign count_o    = count_r;
  assign overflow_o = (count_pls_1 == limit_i);

endmodule
