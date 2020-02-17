/*
* qcl_counter_reset_en.v
*
* simple +1 counter, reset has priority over enable
*/

module qcl_counter_reset_en #(
  parameter width_p = "inv"
  , parameter max_val_lp = width_p'(-1)  // Tested using synopsys vcs and Vivado
  , parameter enable_warning = 1
) (
  input                clk_i
  ,input                reset_i
  ,input                en_i
  ,output [width_p-1:0] count_o
);

  logic [width_p-1:0] count_r;

  always_ff @(posedge clk_i) begin
    if (reset_i)
      count_r <= '0;
    else if (en_i)
      count_r <= count_r + 1'b1;
  end

  assign count_o = count_r;

if (enable_warning) begin
  //synopsys translate_off
    always_ff @ (negedge clk_i) begin
      if ((count_o==max_val_lp) & en_i & (reset_i==1'b0))
        $display("## [%m] Warning: counter overflow at time %t", $time);
    end
  //synopsys translate_on
end

endmodule
