/*
* qcl_change_endian.v
*
* swap the endian of the bytes
*/

module qcl_change_endian #(
  parameter width_p = "inv"
  ,localparam byte_num_lp = width_p/8
) (
  input  [byte_num_lp-1:0][7:0] data_i
  ,
  output [byte_num_lp-1:0][7:0] data_o
);

  for (genvar i=0; i<byte_num_lp; i++) begin
    assign data_o[i] = data_i[byte_num_lp-i-1];
  end

  // synopsys translate_off
  initial begin
    assert (width_p == byte_num_lp * 8 )
      else $error("## [%m]: the data width %d is not the multiple of 8\n", width_p );
  end
  // synopsys translate_on

endmodule
