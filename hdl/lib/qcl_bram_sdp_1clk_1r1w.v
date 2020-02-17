/*
* qcl_bram_sdp_1clk_1r1w.v
*
* Xilinx Simple Dual Port Single Clock RAM, 1 clock read/write latency
* This code implements a parameterizable SDP single clock memory.
*
*/

module qcl_bram_sdp_1clk_1r1w #(
  parameter width_p = "inv"
  , parameter els_p = "inv"
  , localparam addr_width_lp =`BSG_SAFE_CLOG2(els_p)
  , parameter init_file_p = ""
  , parameter harden_p = 1
) (
  input                      clk_i
  ,input                      w_v_i
  ,input  [addr_width_lp-1:0] w_addr_i
  ,input  [      width_p-1:0] w_data_i
  ,input                      r_v_i
  ,input  [addr_width_lp-1:0] r_addr_i
  ,output [      width_p-1:0] r_data_o
);

  wire w_en_li = w_v_i;

  xilinx_simple_dual_one_clock #(
    .ram_width_p(width_p    ),
    .ram_depth_p(els_p      ),
    .init_file_p(init_file_p)
  ) xilinx_bram (
    .clk_i   (clk_i   ),
    .w_v_i   (w_v_i   ),
    .w_en_i  (w_en_li ),
    .w_addr_i(w_addr_i),
    .w_data_i(w_data_i),
    .r_v_i   (r_v_i   ),
    .r_addr_i(r_addr_i),
    .r_data_o(r_data_o)
  );

  // (* ram_style="block" *) logic [width_p-1:0] mem[els_p-1:0];

  // always_ff @(posedge clk_i) begin
  //   if (w_v_i)
  //     mem[w_addr_i] <= w_data_i;
  //   if (r_v_i)
  //     r_data_r <= mem[r_addr_i];
  // end

  // assign r_data_o = r_data_r;


  // // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  // generate
  //   if (init_file_p != "") begin: use_init_file
  //     initial
  //       $readmemh(init_file_p, mem, 0, els_p-1);
  //   end
  //   else begin: init_bram_to_zero
  //     integer ram_index;
  //     initial
  //       for (ram_index = 0; ram_index < els_p; ram_index = ram_index + 1)
  //         mem[ram_index] = {width_p{1'b0}};
  //   end
  // endgenerate

endmodule


module xilinx_simple_dual_one_clock #(
  parameter ram_width_p = "inv"                       // Specify RAM data width
  , parameter ram_depth_p = "inv"                     // Specify RAM depth (number of entries)
  , localparam addr_width_lp =`BSG_SAFE_CLOG2(ram_depth_p)
  , parameter init_file_p = ""                        // Specify name/location of RAM initialization file if using one (leave blank if not)
) (
  input                          clk_i
  ,input                          w_v_i
  ,input                          w_en_i
  ,input      [addr_width_lp-1:0] w_addr_i
  ,input      [  ram_width_p-1:0] w_data_i
  ,input                          r_v_i
  ,input      [addr_width_lp-1:0] r_addr_i
  ,output reg [  ram_width_p-1:0] r_data_o
);

  reg [ram_width_p-1:0] bram_mem[ram_depth_p-1:0] = '{ram_depth_p{(ram_width_p)'(0)}};

  // The following code either initializes the memory values to a specified file or to all zeros to match hardware
  generate
    if (init_file_p != "") begin: use_init_file
      initial
        $readmemh(init_file_p, bram_mem, 0, ram_depth_p-1);
    // end else begin: init_bram_to_zero
    //   integer ram_index;
    //   initial
    //     for (ram_index = 0; ram_index < ram_depth_p; ram_index = ram_index + 1)
    //       bram_mem[ram_index] = {ram_width_p{1'b0}};
    end
  endgenerate

  always_ff @(posedge clk_i) begin
    if (w_v_i) begin
      if (w_en_i)
        bram_mem[w_addr_i] <= w_data_i;
    end
  end

  always_ff @(posedge clk_i) begin
    if (r_v_i)
      r_data_o <= bram_mem[r_addr_i];
  end

  //     end else begin: output_register

  //       // The following is a 2 clock cycle read latency with improve clock-to-out timing

  //       reg [ram_width_p-1:0] doutb_reg = {ram_width_p{1'b0}};

  //       always @(posedge clk_i)
  //         if (r_reset_i)
  //           doutb_reg <= {ram_width_p{1'b0}};
  //         else if (r_reg_en_i)
  //           doutb_reg <= data_r;

  //         assign r_data_o = doutb_reg;

  //       end
  //     endgenerate

endmodule


