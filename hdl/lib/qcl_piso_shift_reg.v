/*
* qcl_piso_shift_reg.v
*
* accept the register array and shift out elements
* valid handshake is used in this module for simplicity
* input is helpful, output is demanding.
*/

module qcl_piso_shift_reg #(
  parameter width_p = 'X
  , parameter els_p = 'X
  , parameter hi_to_lo_p = 0
) (
  input                      clk_i
  ,input                      load_i
  ,input                      shift_i
  ,input  [els_p*width_p-1:0] data_i
  ,output [      width_p-1:0] data_o
);

  logic [  els_p-1:0][width_p-1:0] data_li ;
  logic [width_p-1:0][  els_p-1:0] data_t_n, data_t_r;

  if (hi_to_lo_p == 0) begin : l2h
    assign data_li = data_i;
  end
  else begin : h2l
    bsg_array_reverse #(
      .width_p(width_p),
      .els_p  (els_p  )
    ) mirror (
      .i(data_i ),
      .o(data_li)
    );
  end

  bsg_transpose #(
    .width_p(width_p),
    .els_p  (els_p  )
  ) register_transpose (
    .i(data_li ),
    .o(data_t_n)
  );

  logic [width_p-1:0] data_lo;

  for (genvar i = 0; i < width_p; i++) begin : lshift
    always_ff @(posedge clk_i) begin
      if (load_i)
        data_t_r[i] <= data_t_n[i];
      else if (shift_i)
        data_t_r[i] <= {data_t_r[i][els_p-2:0], 1'b0};
    end
    always_comb begin
      data_lo[i] <= data_t_r[i][els_p-1];
    end
  end
  assign data_o = data_lo;

  //synopsys translate_off
  initial begin
    assert (els_p > 1)
      else $fatal(0, "## [%m] : Parameter els_p is invalid!\n");
  end
  //synopsys translate_on

endmodule
