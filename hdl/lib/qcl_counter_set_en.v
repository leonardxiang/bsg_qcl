/*
* qcl_counter_set_en.v
*
* simple +1 counter, set has priority over enable
*/

module qcl_counter_set_en #(
  parameter width_p = "inv"
  , parameter max_val_lp = width_p'(-1)  // Tested using synopsys vcs and Vivado
) (
  input                clk_i
  ,input                set_i
  ,input  [width_p-1:0] val_i
  ,input                en_i
  ,output [width_p-1:0] count_o
);

  logic [width_p-1:0] count_r;

  always_ff @(posedge clk_i) begin
    if (set_i)
      count_r <= val_i;
    else if (en_i)
      count_r <= count_r + 1'b1;
  end

  assign count_o = count_r;

//synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if ((count_o==max_val_lp) & en_i & (set_i==1'b0) || (val_i>max_val_lp) & (set_i==1'b1))
      $display("%m error: counter overflow at time %t", $time);
  end
//synopsys translate_on

endmodule
