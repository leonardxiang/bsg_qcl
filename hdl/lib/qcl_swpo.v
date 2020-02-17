/*
* qcl_swpo.v
*
* store the input data using addressed registers
* if address is not in range, valid is disabled
*/

`include "bsg_defines.v"

module qcl_swpo #(
  parameter width_p = "inv"
  , parameter addr_width_p = "inv"
  , parameter els_p = "inv"
) (
  input                                  clk_i
  ,input                                  reset_i
  ,input                                  v_i
  ,input  [     width_p-1:0]              data_i
  ,input  [addr_width_p-1:0]              addr_i
  ,output [       els_p-1:0][width_p-1:0] data_o
  ,output                                 v_o
);

  localparam lg_els_lp = `BSG_SAFE_CLOG2(els_p);

  logic [els_p-1:0][width_p-1:0] data_r, data_n;

  always_ff @(posedge clk_i) begin
    if (reset_i)
      data_r <= '0;
    else
      data_r <= data_n;
  end

  always_comb begin: update_registers
    data_n = data_r;
    if (v_i & !(|addr_i[addr_width_p-1:lg_els_lp]))
      data_n[lg_els_lp'(addr_i)] = data_i;
  end

  // support bypass
  assign data_o = data_n;
  assign v_o    = (addr_i == addr_width_p'(els_p-1) & v_i);

endmodule
