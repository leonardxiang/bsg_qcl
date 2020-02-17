/*
* qcl_scratchpad_1pr1w.v
*
*/

module qcl_scratchpad_1pr1w #(
  parameter width_p = "inv"
  , parameter els_p = "inv"
  , localparam addr_width_lp = $clog2(els_p)
) (
  input                                   clk_i
  ,input                                   w_en_i
  ,input  [addr_width_lp-1:0]              addr_i
  ,input  [      width_p-1:0]              data_i
  ,output [        els_p-1:0][width_p-1:0] data_o
);

  (* ram_style="distributed" *) logic [els_p-1:0][width_p-1:0] regs;

  always @(posedge clk_i)
    if (w_en_i)
      regs[addr_i] <= data_i;

  assign data_o = regs;

//synopsys translate_off
  initial begin
    $display("# [%m]: Scratchpad memory instantiating width_p=%d, els_p=%d", width_p, els_p);
  end
  always_ff @(negedge clk_i) begin
    if (w_en_i)
      assert ((addr_i < els_p))
        else $fatal(0, "Invalid address range %x to %m of size %x\n", addr_i, els_p);
  end
//synopsys translate_on

endmodule
