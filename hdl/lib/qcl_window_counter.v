/*
* qcl_window_counter.v
*
* a simple free running delay counter
* @win_o is open for val_p cycles
* @last_o is valid for the last window cycle, or the bypass cycle
*
* val_p:        5
* start:        1  0  0  0  0  0  0  0  0  0
*               |START
* !count_on_start: |BEGIN      |LAST
* count_r:         0  1  2  3  4  5
* window :         |______________|
*/

module qcl_window_counter #(
  parameter width_p = "inv"
  ,parameter enable_bypass_p = 0
) (
  input                clk_i
  ,input                start_i  // self reset
  ,input  [width_p-1:0] len_i
  ,output               win_o
  ,output [width_p-1:0] count_o
  ,output               last_o
);

`ifdef FPGA_LESS_RST
  logic               counting = '0;
  logic [width_p-1:0] cnt_r    = '0;
`else
  logic               counting;
  logic [width_p-1:0] cnt_r   ;
`endif

  wire [width_p-1:0] cnt_pls_1 = cnt_r + 1'b1;

  assign count_o = cnt_r;
  assign win_o   = counting;

  if (enable_bypass_p==0) begin : no_bypass

    assign last_o = counting & (cnt_pls_1 == len_i);

    always_ff @(posedge clk_i) begin
      if (start_i) begin
        counting <= 1'b1;
        cnt_r    <= 1'b0;
      end
      else if (last_o) begin
        counting <= 1'b0;
        cnt_r    <= 1'b0;
      end
      else if (counting)
        cnt_r <= cnt_pls_1;
    end
  end : no_bypass

  else begin : is_bypass

    assign last_o = (len_i == 0) ? start_i : counting & (cnt_pls_1 == len_i);

    always_ff @(posedge clk_i) begin
      if (start_i & ~(len_i==0)) begin
        counting <= 1'b1;
        cnt_r    <= 1'b0;
      end
      else if (last_o) begin
        counting <= 1'b0;
        cnt_r    <= 1'b0;
      end
      else if (counting)
        cnt_r <= cnt_pls_1;
    end
  end : is_bypass

  //synopsys translate_off
  always_ff @(posedge clk_i) begin
    if (start_i & counting)
      $display("## [%m] Warning: Timer restart while counting at time %t", $time);
  end
  // synopsys translate_on

endmodule
