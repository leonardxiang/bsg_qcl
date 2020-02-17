/*
* qcl_delay_cycles.v
*
* a simple delay module, with counter cycles_p = e.g. 4
* d_i   : 0 1
* cnt_en: 0 0 1 1 1 1 0
* cnt_r : 0 0 1 2 3 4 5
* cnt+1 : 0 1 2 3 4 5 6
* d_o   : 0 0 0 0 0 1 0
*/

module qcl_delay_cycles #(parameter cycles_p = 'X) (
  input  clk_i
  ,input  reset_i
  ,input  d_i
  ,output d_o
);

  localparam cnt_width_lp = $clog2(cycles_p+1);

`ifdef FPGA_LESS_RST
  logic                    counting = '0;
  logic [cnt_width_lp-1:0] cnt_r    = '0;
`else
  logic                    counting;
  logic [cnt_width_lp-1:0] cnt_r   ;
`endif

  wire [cnt_width_lp-1:0] cnt_pls_1  = cnt_r + 1'd1         ;
  wire                    overflow_n = cnt_pls_1 == cycles_p;

  logic overflow_r;

  always_ff @(posedge clk_i) begin
  `ifndef FPGA_LESS_RST
    if (reset_i)
      counting <= 1'b0;
    else
  `endif
    if (d_i)
      counting <= 1'b1;
    else if (overflow_r)
      counting <= 1'b0;
  end

  always_ff @(posedge clk_i) begin
  `ifndef FPGA_LESS_RST
    if (reset_i)
      cnt_r <= '0;
    else
  `endif
    if (d_i)
      cnt_r <= cnt_width_lp'(1);  // next cycle of d_i is 1
    else if (counting)
      cnt_r <= cnt_r + 1'b1;
  end

  always_ff @(posedge clk_i) begin
    overflow_r <= overflow_n;
  end

  assign d_o = overflow_r & counting;

  //synopsys translate_off
  initial begin
    assert (cycles_p >= 1)
      else $fatal(0, "## [%m] Parameter cycles_p should > 2!");
  end
  always_ff @(posedge clk_i) begin
    if (d_i & counting)
      $display("## [%m] Warning: Timer restart while counting at time %t",$time);
  end
  // synopsys translate_on

endmodule
