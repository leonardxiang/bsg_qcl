/*
* mmcme2_125_to_25_250_500x2.v
* Clocking PRIMITIVE
*------------------------------------
* Instantiation of the MMCM PRIMITIVE
*    * Unused inputs are tied off
*    * Unused outputs are labeled unused
*/

module mmcme2_125_to_25_250_500x2 #(parameter lvds_phase_p = 0.000
) (
  input  clk_i
  ,input  reset_i
  ,output clk0_o
  ,output clk1_o
  ,output clk2_o
  ,output clk3_o
  ,output locked_o
);

  wire clk_25;
  wire clk_250;
  wire clk_500a;
  wire clk_500b;

  wire clk_fb_lo       ;
  wire clkfboutb_unused;
  wire clk_fb_li       ;

  wire clkout0b_unused;
  wire clkout1b_unused;
  wire clkout2b_unused;
  wire clkout3b_unused;
  wire clkout4_unused ;
  wire clkout5_unused ;
  wire clkout6_unused ;


  wire [15:0] do_unused          ;
  wire        drdy_unused        ;
  wire        psdone_unused      ;
  wire        clkfbstopped_unused;
  wire        clkinstopped_unused;

  MMCME2_ADV #(
    .BANDWIDTH           ("OPTIMIZED"),
    .CLKOUT4_CASCADE     ("FALSE"    ),
    .COMPENSATION        ("ZHOLD"    ),
    .STARTUP_WAIT        ("FALSE"    ),
    .DIVCLK_DIVIDE       (1          ),
    .CLKFBOUT_MULT_F     (8.000      ),
    .CLKFBOUT_PHASE      (0.000      ),
    .CLKFBOUT_USE_FINE_PS("FALSE"    ),

    .CLKOUT0_DIVIDE_F    (40.000     ),
    .CLKOUT0_PHASE       (0.000      ),
    .CLKOUT0_DUTY_CYCLE  (0.500      ),
    .CLKOUT0_USE_FINE_PS ("FALSE"    ),

    .CLKOUT1_DIVIDE      (4          ),
    .CLKOUT1_PHASE       (0.000      ),
    .CLKOUT1_DUTY_CYCLE  (0.500      ),
    .CLKOUT1_USE_FINE_PS ("FALSE"    ),

    .CLKOUT2_DIVIDE      (2          ),
    .CLKOUT2_PHASE       (lvds_phase_p),
    .CLKOUT2_DUTY_CYCLE  (0.500      ),
    .CLKOUT2_USE_FINE_PS ("FALSE"    ),

    .CLKOUT3_DIVIDE      (2          ),
    .CLKOUT3_PHASE       (lvds_phase_p),
    .CLKOUT3_DUTY_CYCLE  (0.500      ),
    .CLKOUT3_USE_FINE_PS ("FALSE"    ),

    .CLKIN1_PERIOD       (8.000      )
  ) mmcm_adv_inst (
    .CLKFBOUT    (clk_fb_lo          ),
    .CLKFBOUTB   (clkfboutb_unused   ),
    .CLKOUT0     (clk_25           ),
    .CLKOUT0B    (clkout0b_unused    ),
    .CLKOUT1     (clk_250           ),
    .CLKOUT1B    (clkout1b_unused    ),
    .CLKOUT2     (clk_500a           ),
    .CLKOUT2B    (clkout2b_unused    ),
    .CLKOUT3     (clk_500b           ),
    .CLKOUT3B    (clkout3b_unused    ),
    .CLKOUT4     (clkout4_unused     ),
    .CLKOUT5     (clkout5_unused     ),
    .CLKOUT6     (clkout6_unused     ),
    // Input clock control
    .CLKFBIN     (clk_fb_li          ),
    .CLKIN1      (clk_i              ),
    .CLKIN2      (1'b0               ),
    // Tied to always select the primary input clock
    .CLKINSEL    (1'b1               ),
    // Ports for dynamic reconfiguration
    .DADDR       (7'h0               ),
    .DCLK        (1'b0               ),
    .DEN         (1'b0               ),
    .DI          (16'h0              ),
    .DO          (do_unused          ),
    .DRDY        (drdy_unused        ),
    .DWE         (1'b0               ),
    // Ports for dynamic phase shift
    .PSCLK       (1'b0               ),
    .PSEN        (1'b0               ),
    .PSINCDEC    (1'b0               ),
    .PSDONE      (psdone_unused      ),
    // Other control and status signals
    .LOCKED      (locked_o           ),
    .CLKINSTOPPED(clkinstopped_unused),
    .CLKFBSTOPPED(clkfbstopped_unused),
    .PWRDWN      (1'b0               ),
    .RST         (reset_i            )
  );

  BUFG clkf_buf (.O(clk_fb_li), .I(clk_fb_lo));

// Clock Monitor clock assigning
//--------------------------------------
// Output buffering
//-----------------------------------

  BUFG clkout0_buf (.O(clk0_o), .I(clk_25));

  BUFG clkout1_buf (.O(clk1_o), .I(clk_250));

  BUFG clkout2_buf (.O(clk2_o), .I(clk_500a));

  BUFG clkout3_buf (.O(clk3_o), .I(clk_500b));

endmodule
