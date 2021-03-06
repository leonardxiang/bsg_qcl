/*
* qcl_debounce.v
*
* @param width_p defines the debounce time MSB. Assuming 100 MHz clock,
* the debounce time is 2^(22-1)/ 100 MHz KHz = 20 ms
* For 50 MHz clock, change the value of width_p accordingly to 21.
*
*/

module qcl_debounce #(parameter width_p = 22) (
  input  clk_i
  ,input  i
  ,output o
);

  logic [width_p-1:0] time_r, time_n;

  logic i_1r, i_2r;

  wire glitch = (i_1r  ^ i_2r);  // xor on conecutive clocks to detect level change

  wire cnt_en = ~(time_r[width_p-1]); // Check count using MSB of counter

  always_comb begin
    if (glitch)
      time_n = '0;
    else if (cnt_en)
      time_n = time_r + 1'b1;
    else
      time_n = time_r;
  end

  logic o_r ;

  always_ff @( posedge clk_i ) begin
    i_1r   <= i;
    i_2r   <= i_1r;
    time_r <= time_n;
    o_r    <= time_r[width_p-1] ? i_2r : o_r;
  end

  assign o = o_r;

endmodule
