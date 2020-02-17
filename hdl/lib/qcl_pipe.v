/*
* qcl_pipe.v
*
* simple pipline, derived from aws lib_pipe.sv
*/

//stages_p is the number of stages (flops in the pipeline)
module qcl_pipe #(
  parameter width_p = 1
  , parameter stages_p = 1
) (
  input                clk_i
  ,input                reset_i
  ,input  [width_p-1:0] d_i
  ,output [width_p-1:0] d_o
);

  //Note the shreg_extract=no directs Xilinx to not infer shift registers which
  //defeats using this as a pipeline
  `ifdef FPGA_LESS_RST
    (*shreg_extract="no"*) logic [stages_p-1:0][width_p-1:0] pipe_r = '0;
  `else
    (*shreg_extract="no"*) logic [stages_p-1:0][width_p-1:0] pipe_r;
  `endif

  //(*srl_style="register"*) logic [width_p-1:0] pipe_r [stages_p-1:0];
  //logic [width_p-1:0] pipe_r [stages_p-1:0];

  integer i;

  always_ff @(posedge clk_i)
  `ifndef FPGA_LESS_RST
    if (reset_i) begin
      for (i = 0; i < stages_p; i = i + 1)
        pipe_r[i] <= '0;
    end
    else
  `endif
    begin
      // stages_p == 1
      pipe_r[0] <= d_i;
      //
      if (stages_p > 1) begin
        for (i = 1; i < stages_p; i = i + 1)
          pipe_r[i] <= pipe_r[i-1];
      end
    end

  assign d_o = pipe_r[stages_p-1];

endmodule
