/*
* qcl_decode_priority.v
*
*/

module qcl_decode_priority #(
  parameter width_p = "inv"
  , parameter lo_to_hi_p = 1
) (
  input        [`BSG_WIDTH(width_p)-1:0] i
  ,output logic [            width_p-1:0] o
);

  wire [width_p-1:0] stuff = '1;

  if (width_p == 1) begin
    // suppress unused signal warning
    wire unused = i;
    assign o = 1'b1;
  end
  else begin
    if (lo_to_hi_p)
      assign o = ~((width_p) ' (stuff << i));
    else
      assign o = ~((width_p) ' (stuff >> i));
  end

  // synopsys translate_off
  initial begin
    assert(width_p >= 1)
      else $fatal(0, "[%m] width_p should be larger than 0!\n");
  end
  // synopsys translate_on

endmodule
