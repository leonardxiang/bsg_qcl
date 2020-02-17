/*
* qcl_mult.v
*
*/

module qcl_mult #(
  parameter width_p = "inv"
  , parameter latency_p = 0
  , parameter harden_p = 0
  , parameter device_family = "7SERIES"
) (
  input                  clk_i
  ,input                  reset_i
  ,input                  en_i
  ,input  [  width_p-1:0] a_i
  ,input  [  width_p-1:0] b_i
  ,output [2*width_p-1:0] p_o
);


  if (harden_p==0) begin : synth
    // + 0
    if (latency_p==0)
      assign p_o = reset_i ? '0 : en_i ? (a_i * b_i) : '0;
    // + 1
    else if (latency_p==1) begin
      logic [2*width_p-1:0] p_r;
      always_ff @(posedge clk_i) begin
        if (reset_i)
          p_r <= '0;
        else if (en_i)
          p_r <= a_i * b_i;
      end
    end
    //  + 2
    else if (latency_p==2) begin
      logic [width_p-1:0] a_r, b_r;
      logic [2*width_p-1:0] p_r;
      always_ff @(posedge clk_i) begin
        if (reset_i) begin
          a_r <= '0;
          b_r <= '0;
          p_r <= '0;
        end
        else if (en_i) begin
          a_r <= a_i;
          b_r <= b_i;
          p_r <= a_r * b_r;
        end
      end
    end
    // + x
    else
      $fatal(0, "[%m] Parameter latency_p should be either 0,1,2 when harden_p=0");
  end : synth

  else begin : xilinx_ip

    // MULT_MACRO: Multiply Function implemented in a DSP48E
    //             Kintex-7
    // Xilinx HDL Language Template, version 2019.1

    MULT_MACRO #(
      .DEVICE (device_family), // Target Device: "7SERIES"
      .LATENCY(latency_p), // Desired clock cycle latency, 0-4
      .WIDTH_A(width_p  ), // Multiplier A-input bus width, 1-25
      .WIDTH_B(width_p  )  // Multiplier B-input bus width, 1-18
    ) MULT_MACRO_inst (
      .P  (p_o    ), // Multiplier output bus, width determined by WIDTH_P parameter
      .A  (a_i    ), // Multiplier input A bus, width determined by WIDTH_A parameter
      .B  (b_i    ), // Multiplier input B bus, width determined by WIDTH_B parameter
      .CE (en_i   ), // 1-bit active high input clock enable
      .CLK(clk_i  ), // 1-bit positive edge clock input
      .RST(reset_i)  // 1-bit input active high reset
    );

    // End of MULT_MACRO_inst instantiation

  end : xilinx_ip

endmodule
