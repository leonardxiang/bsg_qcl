/*
* qcl_add_sub.v
*
* unsigned add
*/

module qcl_add_sub #(
  parameter width_p = "inv"
  ,parameter latency_p = 0
  ,parameter is_add_not_sub_p = "inv"
  ,parameter harden_p = 0
  ,parameter device_family = "7SERIES"
) (
  input                clk_i
  ,input                reset_i
  ,input  [width_p-1:0] a_i
  ,input  [width_p-1:0] b_i
  ,output [width_p-1:0] s_o
  ,output               c_o
);

  if (harden_p==0) begin : synth
    // + 0
    if (latency_p==0) begin : comb
      if (is_add_not_sub_p)
        assign {c_o, s_o} = reset_i ? '0 : (a_i + b_i);
      else
        assign {c_o, s_o} = reset_i ? '0 : (a_i - b_i);
    end : comb
    // + 1
    else if (latency_p==1) begin : seq
      logic [width_p-1:0] s_r;
      logic               c_r;
      assign s_o = s_r;
      assign c_o = c_r;
      always_ff @(posedge clk_i) begin
        if (reset_i)
          {c_r, s_r} <= '0;
        else begin
          if (is_add_not_sub_p)
            {c_r, s_r} <= a_i + b_i;
          else
            {c_r, s_r} <= a_i - b_i;
        end
      end
    end : seq
    // + x
    else
      $fatal(0, "[%m] Parameter latency_p should be either 0 or 1 when harden_p=0");
  end : synth

  else begin : xilinx_ip

    // ADDSUB_MACRO: Variable width & latency - Adder / Subtracter implemented in a DSP48E
    //               Kintex-7
    // Xilinx HDL Language Template, version 2019.1

    ADDSUB_MACRO #(
      .DEVICE (device_family), // Target Device: "7SERIES"
      .LATENCY(latency_p), // Desired clock cycle latency, 0-2
      .WIDTH  (width_p  )  // Input / output bus width, 1-48
    ) ADDSUB_MACRO_inst (
      .CARRYOUT(c_o             ), // 1-bit carry-out output signal
      .RESULT  (s_o             ), // Add/sub result output, width defined by WIDTH parameter
      .A       (a_i             ), // Input A bus, width defined by WIDTH parameter
      .ADD_SUB (is_add_not_sub_p), // 1-bit add/sub input, high selects add, low selects subtract
      .B       (b_i             ), // Input B bus, width defined by WIDTH parameter
      .CARRYIN ('0              ), // 1-bit carry-in input
      .CE      (1'b1            ), // 1-bit clock enable input // careful if using clock enable, latency may not as expected
      .CLK     (clk_i           ), // 1-bit clock input
      .RST     (reset_i         )  // 1-bit active high synchronous reset
    );

    // End of ADDSUB_MACRO_inst instantiation

  end : xilinx_ip

endmodule
