/*
* qcl_domino.v
*
* set a series of registerd to 0/1 and revers in domino fashion
* 11111 -> 11110 -> 11100 -> 11000 -> 10000 -> 00000
* output MSB
*/

module qcl_domino #(
  parameter els_p = "inv"
  , parameter val_p = 1'b1
) (
  input  clk_i
  ,input  i
  ,output o
);

  (*shreg_extract="no"*) logic [els_p-1:0] o_r;

  always_ff @(posedge clk_i) begin
    if (i)
      o_r <= {els_p{1'(val_p)}};
    else
      o_r <= {o_r[els_p-2:0], ~(1'(val_p))};
  end

  assign o = o_r[els_p-1];

  //synopsys translate_off
  initial begin
    assert(els_p >=2)
      else $error("## [%m]: Elements must >= 2, actual value is %d\n", els_p);
  end
  //synopsys translate_on

endmodule
