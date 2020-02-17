/*
* qcl_counter_underflow_set_en.v
*
* simple down counter, with load has priority over enable
*
* Author       Liang Xiang
* Email:       xlelephant@gmail.com
* CREATED      "Mon Apr 23 09:35:36 2018"
* MODIFIED     "Thu Apr 26 11:43:22 2018"
*/

module qcl_counter_underflow_set_en #(parameter width_p = "inv") (
  input                clk_i
  ,input                set_i
  ,input                en_i
  ,input  [width_p-1:0] val_i
  ,output [width_p-1:0] count_o
  ,output               underflow_o
);

  logic [width_p-1:0] count_r;

  always_ff @(posedge clk_i) begin
    if (set_i)
      count_r <= val_i;
    else if(en_i)
      count_r <= count_r - 1'b1;
  end

  assign count_o     = count_r;
  assign underflow_o = (count_r == '0);

endmodule
