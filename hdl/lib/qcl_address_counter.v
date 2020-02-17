/*
* qcl_address_counter.v
* supposed to be used to generate memory mapped address from stream data
* limit:    5 - - - - - - - - -  5  5  5
* start:    1                 |last
* count:    0  1  1  - - - -  1  0  0  0
* valid:       1  1  1  0  1  1  1  1  1
* addr :    0  0  1  2  3  3  4  5  6  6
*
*/

module qcl_address_counter #(parameter width_p = "inv") (
  input                clk_i
  ,input                reset_i
  ,input                start_i  // note: start is earlier than valid
  ,input                en_i     // valid -> ready interface
  ,input  [width_p-1:0] limit_i
  ,output [width_p-1:0] addr_o
  ,output               v_o
  ,output               last_o
);

  logic counting;

  always_ff @(posedge clk_i) begin
    if (reset_i)
      counting <= 1'b0;
    else if (start_i)
      counting <= 1'b1;
    else if (last_o & en_i)  // last_o has lower priority
      counting <= 1'b0;
    else
      counting <= counting;
  end

  assign v_o = counting;

  wire cnt_rest_li = reset_i | ~counting;

  qcl_counter_dynamic_limit_en #(.width_p(width_p)) address_counter (
    .clk_i     (clk_i          ),
    .reset_i   (cnt_rest_li    ),  // if overflow, counter auto reset
    .en_i      (counting & en_i),
    .limit_i   (limit_i        ),
    .count_o   (addr_o         ),
    .overflow_o(last_o         )
  );

  //synopsys translate_off
  always_ff @(posedge clk_i)
    if (start_i)
      assert(last_o & en_i | (counting == 0))
        else $fatal(0, "## [%m]: Can not start the address counter when counting.\n");
  // synopsys translate_on

endmodule
