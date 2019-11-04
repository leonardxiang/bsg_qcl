//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/30/2017 11:16:59 AM
// Design Name: 
// Module Name: app2axi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines_h.vh"
`timescale 1ps / 1ps
module app2axi #(
  parameter APP_DATA_WIDTH		= 32,			// DDR data bus width.
  parameter APP_ADDR_WIDTH		= 29,			// Address bus width of the 
  parameter APP_CMD_WIDTH		= 3,
  parameter DM_WIDTH			= 8,
  parameter C_AXI_ID_WIDTH		= 4,
  parameter C_AXI_ADDR_WIDTH    = APP_ADDR_WIDTH, 
  parameter C_AXI_DATA_WIDTH    = APP_DATA_WIDTH,
  parameter TCQ                 = 0	
)(
	input										i_clk,
	input										i_rst,
	output										o_wrt_rqt_over_flow,
	// DDR3/4, RLD3, QDRIIP Shared Interface
	input	[APP_CMD_WIDTH-1 : 0]				app_cmd, // command bus to the MC UI
	input	[APP_ADDR_WIDTH-1 : 0]				app_addr, // address bus to the MC UI
	input										app_en, // command enable signal to MC UI.
	input	[(APP_DATA_WIDTH/DM_WIDTH)-1 : 0]	app_wdf_mask, // write data mask signal which // is tied to 0 in this example.
	input [APP_DATA_WIDTH-1: 0]					app_wdf_data, // write data bus to MC UI.
	input										app_wdf_end, // write burst end signal to MC UI
	input										app_wdf_wren, // write enable signal to MC UI
	// QDRIIP Interface
	input										app_wdf_en,		// QDRIIP, write enable
	input [APP_ADDR_WIDTH-1:0]					app_wdf_addr,	// QDRIIP, write address
	input [APP_CMD_WIDTH-1:0]					app_wdf_cmd,	// QDRIIP write command

	output										app_rdy, // cmd fifo ready signal coming from MC UI.
	output										app_wdf_rdy, // write data fifo ready signal coming from MC UI.
	output										app_rd_data_valid, // read data valid signal coming from MC UI
	output	[APP_DATA_WIDTH-1 : 0]				app_rd_data, // read data bus coming from MC UI

// AXI write address channel signals
	input										axi_awready, // Indicates slave is ready to accept a 
	output [C_AXI_ID_WIDTH-1:0]					axi_awid,    // Write ID
	output [C_AXI_ADDR_WIDTH-1:0]				axi_awaddr,  // Write address
	output [7:0]								axi_awlen,   // Write Burst Length
	output [2:0]								axi_awsize,  // Write Burst size
	output [1:0]								axi_awburst, // Write Burst type
	output										axi_awlock,  // Write lock type
	output [3:0]								axi_awcache, // Write Cache type
	output [2:0]								axi_awprot,  // Write Protection type
	output										axi_awvalid, // Write address valid
// AXI write data channel signals
  input											axi_wready,  // Write data ready
  output [C_AXI_DATA_WIDTH-1:0]					axi_wdata,    // Write data
  output [C_AXI_DATA_WIDTH/8-1:0]				axi_wstrb,    // Write strobes
  output										axi_wlast,    // Last write transaction   
  output										axi_wvalid,   // Write valid  
// AXI write response channel signals
  input  [C_AXI_ID_WIDTH-1:0]					axi_bid,     // Response ID
  input  [1:0]									axi_bresp,   // Write response
  input											axi_bvalid,  // Write reponse valid
  output										axi_bready,  // Response ready
// AXI read address channel signals
  input											axi_arready,     // Read address ready
  output [C_AXI_ID_WIDTH-1:0]					axi_arid,        // Read ID
  output [C_AXI_ADDR_WIDTH-1:0]					axi_araddr,      // Read address
  output [7:0]									axi_arlen,       // Read Burst Length
  output [2:0]									axi_arsize,      // Read Burst size
  output [1:0]									axi_arburst,     // Read Burst type
  output										axi_arlock,      // Read lock type
  output [3:0]									axi_arcache,     // Read Cache type
  output [2:0]									axi_arprot,      // Read Protection type
  output										axi_arvalid,     // Read address valid 
// AXI read data channel signals   
  input  [C_AXI_ID_WIDTH-1:0]					axi_rid,     // Response ID
  input  [1:0]									axi_rresp,   // Read response
  input											axi_rvalid,  // Read reponse valid
  input  [C_AXI_DATA_WIDTH-1:0]					axi_rdata,   // Read data
  input											axi_rlast,   // Read last
  output										axi_rready  // Read Response ready
);
	
	//functions
	function integer clogb2 (input integer size);
		begin
			size = size - 1;
		    for (clogb2=1; size>1; clogb2=clogb2+1)
			size = size >> 1;
		end
	endfunction // clogb2

	// LOCAL PARAMETER
	`ifdef OPT_DATA_W
	localparam  LP_AXSIZE       = clogb2(256/8);
	`else
	localparam  LP_AXSIZE       = clogb2(C_AXI_DATA_WIDTH/8);
	`endif
	localparam  LP_COUNTER_WIDHT = 32;


	// WIRE DECLARATION
	wire							w_prvs_wrt_done;
	wire							w_wrt_axfifo_wren;
	wire							w_wrt_axfifo_rden;
	wire	[(APP_ADDR_WIDTH+APP_CMD_WIDTH):0]	w_wrt_axfifo_dout;
	wire							w_wrt_axfifo_full;
	wire							w_wrt_axfifo_empty;
	wire							w_wrt_wfifo_wren;
	wire							w_wrt_wfifo_rden;
	wire	[((APP_DATA_WIDTH/DM_WIDTH)+APP_DATA_WIDTH-1):0]	w_wrt_wfifo_dout;
	wire							w_wrt_wfifo_full;
	wire							w_wrt_wfifo_empty;
	
	wire							w_curr_app_wreq;
	wire							w_curr_app_rreq;
	wire							w_prvs_req_done; 
	wire							w_wrt2rd_chk_prvs_wrt_done;

	// REG DECLARATION
    reg [LP_COUNTER_WIDHT -1:0]  r_count_no_of_wrt;
	reg							r_prvs_req_done; 
	reg	[C_AXI_ID_WIDTH-1:0]	r_axi_wid; 
	reg	[C_AXI_ID_WIDTH-1:0]	r_axi_awid;
	reg							r_wrt_rqt_over_flow;
	// APP Interface 
	// app rdy dpdn on both address FIFO and Data FIFO.

reg w_last_wfifo_wren = 0;
reg w_last_wfifo_din = 0;
reg w_last_len_2 = 0;
wire w_last_wfifo_rden = w_wrt_wfifo_rden;
wire w_last_wfifo_dout;
wire w_last_wfifo_full;
wire w_last_wfifo_empty;

reg [APP_CMD_WIDTH-1 : 0] app_cmd_d1 = 0;
reg [APP_CMD_WIDTH-1 : 0] app_cmd_d2 = 0;
reg [APP_CMD_WIDTH-1 : 0] app_cmd_int = 0;

reg [APP_ADDR_WIDTH-1 : 0] app_addr_d1 = 0;
reg [APP_ADDR_WIDTH-1 : 0] app_addr_d2 = 0;
reg [APP_ADDR_WIDTH-1 : 0] app_addr_int = 0;

reg                        app_en_d1 = 0;
reg                        app_en_d2 = 0;
reg                        app_en_int = 0;

reg                        app_len_int = 0;

// Check for same transaction type: read or write.
// Wait till next valid cycle (app_rdy) only.
// Check for sequential addresses with 32 bytes (256 bit) size. i.e. address increment by 0x20.
// Check for 4KB boundary
always @(posedge i_clk) begin
  if(app_rdy) begin
    app_cmd_d1 <= #TCQ app_cmd;
    app_cmd_d2 <= #TCQ app_cmd_d1;
    app_cmd_int <= #TCQ app_cmd_d2;

    app_addr_d1 <= #TCQ app_addr;
    app_addr_d2 <= #TCQ app_addr_d1;
    app_addr_int <= #TCQ app_addr_d2;

    app_en_d1 <= #TCQ app_en;
    app_en_int <= #TCQ app_en_d2;

    if(app_en_d1 && app_en_d2 && (app_cmd_d1 == app_cmd_d2) && (app_addr_d1 == (app_addr_d2 + 8'h20)) && (app_addr_d1[11:0] !== 12'h0)) begin
      app_en_d2 <= #TCQ 0;
      app_len_int <= #TCQ 1;
    end else begin
      app_en_d2 <= #TCQ app_en_d1;
      app_len_int <= #TCQ 0;
    end
  end
end

always @(posedge i_clk) begin
  if(app_rdy) begin
    if(app_en_int & (app_cmd_int == 0)) begin // Write 
      if(app_len_int == 1) begin
        w_last_wfifo_wren <= #TCQ 1;
        w_last_wfifo_din <= #TCQ 0;
        w_last_len_2 <= #TCQ 1;
      end else begin
        w_last_wfifo_wren <= #TCQ 1;
        w_last_wfifo_din <= #TCQ 1;
        w_last_len_2 <= #TCQ 0;
      end
    end else if(w_last_len_2) begin
      w_last_wfifo_wren <= #TCQ 1;
      w_last_wfifo_din <= #TCQ 1;
      w_last_len_2 <= #TCQ 0;
    end else begin
      w_last_wfifo_wren <= #TCQ 0;
      w_last_wfifo_din <= #TCQ 0;
    end
  end else begin
    w_last_wfifo_wren <= #TCQ 0;
    w_last_wfifo_din <= #TCQ 0;
  end
end

	assign	app_rdy =  ~w_wrt_axfifo_full;
	assign  app_wdf_rdy = ~w_wrt_wfifo_full & ~w_last_wfifo_full;

	assign  o_wrt_rqt_over_flow = r_wrt_rqt_over_flow;

	// AXI: AW channel assign ment
	// if app_cmd is Write command, address
	//assign  axi_awid		= {(C_AXI_ID_WIDTH){1'b0}};
	assign  axi_awid		= r_axi_awid;
	assign  axi_awaddr		= w_curr_app_wreq ? w_wrt_axfifo_dout[APP_ADDR_WIDTH-1:0] : {(APP_ADDR_WIDTH){1'b1}} ;
	assign  axi_awlen		= w_wrt_axfifo_dout[APP_CMD_WIDTH+APP_ADDR_WIDTH]; // 8'd0;
	assign  axi_awsize		= LP_AXSIZE; //n_NM
	assign  axi_awburst		= 2'd1;
	assign  axi_awlock		= 1'b0;
	assign  axi_awcache		= 4'b0000;
	assign  axi_awprot		= 3'b00;
	assign  axi_awvalid		= w_curr_app_wreq;



	//AXI: W channel assign ment
	// if app_wdf_ren goes high app_wdf_data assign ed to axi_wdata and
	// axi_wvalid & axi_wlast goes high.
	assign  axi_wdata	= w_wrt_wfifo_dout[APP_DATA_WIDTH -1:0];
	//assign  axi_wstrb	= {(C_AXI_DATA_WIDTH/8){1'b1}};
	assign  axi_wstrb	= ~w_wrt_wfifo_dout[((APP_DATA_WIDTH/DM_WIDTH)+ APP_DATA_WIDTH -1) : APP_DATA_WIDTH];
	assign  axi_wlast	= w_last_wfifo_dout; // ~w_wrt_wfifo_empty;
	assign  axi_wvalid	= ~w_wrt_wfifo_empty & ~w_last_wfifo_empty;

	// AXI: AR channel 
	assign  axi_arid	= {(C_AXI_ID_WIDTH){1'b0}};	// fir in-order read request
	//assign  axi_arid	= r_axi_awid;
	assign  axi_araddr	= w_curr_app_rreq ? w_wrt_axfifo_dout[APP_ADDR_WIDTH-1:0]: {(APP_ADDR_WIDTH){1'b1}};
	assign  axi_arlen	= w_wrt_axfifo_dout[APP_CMD_WIDTH+APP_ADDR_WIDTH]; // 8'd0;
	assign  axi_arsize	= LP_AXSIZE; //n_NM
	assign  axi_arburst	= 2'b00;
	assign  axi_arlock	= 1'b0;
	assign  axi_arcache	= 4'b0000;
	assign  axi_arprot	= 3'b000;
	assign  axi_arvalid	= w_curr_app_rreq && w_wrt2rd_chk_prvs_wrt_done;

	//AXI: R channel
	// AXI read data channel signals   
	assign 	axi_rready	= 1'b1;  // Read Response ready
	
	// APP Interface Read signals
	assign 	app_rd_data_valid	= axi_rvalid == 1'b1 ? ( axi_rid == {(C_AXI_ID_WIDTH){1'b0}} ) : 1'b0;
	assign 	app_rd_data			= axi_rdata;
	
	//AXI: B channel
	assign  axi_bready = 1'b1;

    // previous write done chk 
    // counter inc wn write happens, dec wn response if valid 
    assign  w_prvs_wrt_done = ( r_count_no_of_wrt == {(LP_COUNTER_WIDHT){1'b0}}) ? 1'b1 : 1'b0;
    
	always @ ( posedge i_clk or posedge i_rst )
        begin
            if( i_rst == 1'b1 )
                begin
                    r_count_no_of_wrt   <= #TCQ {(LP_COUNTER_WIDHT){1'b0}};
					r_wrt_rqt_over_flow	<= 1'b0;
                end
              else
                begin
                    //Inc count with write valid and response not present
                    if(( axi_awvalid == 1'b1 ) && ( axi_awready  == 1'b1 ) && ( axi_bvalid == 1'b0 ))
                        begin
							if(  r_count_no_of_wrt == {(LP_COUNTER_WIDHT){1'b1}} )
								begin
									r_count_no_of_wrt   <= #TCQ r_count_no_of_wrt;
									r_wrt_rqt_over_flow	<= 1'b1;
								end
							else
								begin
									r_wrt_rqt_over_flow	<= 1'b0;
		                            r_count_no_of_wrt   <= #TCQ r_count_no_of_wrt + {{(LP_COUNTER_WIDHT-1){1'b0}}, {1'b1}};
								end
                        end
                     //hold count with Write valid and response at same time
                     else if(( axi_awvalid == 1'b1 ) && ( axi_awready  == 1'b1 ) && ( axi_bvalid == 1'b1 ) && ( axi_bready == 1'b1 ))
                        begin
							r_wrt_rqt_over_flow	<= 1'b0;
                            r_count_no_of_wrt   <= #TCQ r_count_no_of_wrt;
                        end
                     //count dec with write response only
                     else if( ( axi_bvalid == 1'b1 ) && ( axi_bready == 1'b1 ))
                        begin
							r_wrt_rqt_over_flow	<= 1'b0;
                            if( r_count_no_of_wrt > {(LP_COUNTER_WIDHT){1'b0}} )
                                begin
                                    r_count_no_of_wrt   <= #TCQ r_count_no_of_wrt - {{(LP_COUNTER_WIDHT-1){1'b0}}, {1'b1}};
                                end
                            else
                                begin
                                    r_count_no_of_wrt   <= #TCQ {(LP_COUNTER_WIDHT){1'b0}};
                                end
                        end
                    else 
                        begin
							r_wrt_rqt_over_flow	<= r_wrt_rqt_over_flow;
                            r_count_no_of_wrt   <= #TCQ r_count_no_of_wrt;
                        end
                     
                end
        end
// Counting the waddress and wdata to check
// Added by kkavurik
//int count_aw = 0;
//int count_w  = 0;
//always @ (posedge i_clk or posedge i_rst )
//begin
//if (axi_awvalid && axi_awready == 1'b1)
//   begin
//   count_aw = count_aw+1;
//   $display ("The write request count_aw is =%d",count_aw);
//   if (axi_awaddr[36]==1)
//     begin
//     $display (" The address 36th bit axi_awaddr[35:32]=%h",axi_awaddr[35:32]);
//     end
//   end
//   
//
//if (axi_wvalid && axi_wready == 1'b1)
//   begin
//   count_w = count_w+1;
//   $display ("The write request count_w is =%d",count_w);
//   end
//end
//
//initial
//begin
//wait (count_aw == count_w) 
//  $display("The address vs data request count matched"); 
//  end


	// cmd add fifo
	// write to the FIFO -> app_en high with app_rdy.
	assign w_wrt_axfifo_wren = app_en_int & app_rdy;
	assign w_wrt_axfifo_rden = w_prvs_req_done & ~w_wrt_axfifo_empty && w_wrt2rd_chk_prvs_wrt_done && ~r_wrt_rqt_over_flow;

	atg_axi_tg_fifo #(
		.TCQ(TCQ),
		.WIDTH(APP_ADDR_WIDTH+APP_CMD_WIDTH+1),
		.DEPTH(4),
		.LOG2DEPTH(2)
    )	U_atg_axi_FIFO_AXADD (
		.clk (i_clk),
	    .rst (i_rst),
		.wren (w_wrt_axfifo_wren),
		.rden (w_wrt_axfifo_rden),
		.din ({app_len_int, app_cmd_int, app_addr_int}),
		.dout (w_wrt_axfifo_dout),
		.full (w_wrt_axfifo_full),
		.empty (w_wrt_axfifo_empty)
	);

	// FIFO Read condition 
	//  -> fifo not empty,
	//  -> prevs request done( read/write with axi ready signal ).
	//  -> if curr req is read, chk for previous wrt status
	assign w_curr_app_wreq =( w_wrt_axfifo_dout[APP_CMD_WIDTH+APP_ADDR_WIDTH-1:APP_ADDR_WIDTH]== 3'b000 ) && ~w_wrt_axfifo_empty;
	assign w_curr_app_rreq =( w_wrt_axfifo_dout[APP_CMD_WIDTH+APP_ADDR_WIDTH-1:APP_ADDR_WIDTH]== 3'b001 ) && ~w_wrt_axfifo_empty;
	assign w_prvs_req_done = axi_awvalid ? axi_awready : ( axi_arvalid ? axi_arready : w_wrt2rd_chk_prvs_wrt_done); 

	//	->	if curr fifo read instruction is Read, check for all prevs write are
	//		done. before proceeding to next fifo read
	assign w_wrt2rd_chk_prvs_wrt_done = w_curr_app_rreq ? w_prvs_wrt_done : 1'b1;
	//Write DATA fifo
	//app wirte written in to FIFO wn, app wren is asserted with fifo not FULL.
	//Read from FIFO happen, wn axi Wchannel is ready and FIFO not empty. 
	assign w_wrt_wfifo_wren = app_wdf_wren && ~w_wrt_wfifo_full && ~w_last_wfifo_full;
	assign w_wrt_wfifo_rden = axi_wready && ~w_wrt_wfifo_empty && ~w_last_wfifo_empty;

	atg_axi_tg_fifo #(
		.TCQ(TCQ),
		.WIDTH((APP_DATA_WIDTH/DM_WIDTH)+ APP_DATA_WIDTH),
		.DEPTH(8),
		.LOG2DEPTH(3)
    ) U_atg_axi_TG_FIFO_DATA (
	    .clk (i_clk),
		.rst (i_rst),
		.wren (w_wrt_wfifo_wren),
		.rden (w_wrt_wfifo_rden),
		.din ({app_wdf_mask, app_wdf_data}),
		.dout (w_wrt_wfifo_dout),
		.full (w_wrt_wfifo_full),
		.empty (w_wrt_wfifo_empty)
	);

	atg_axi_tg_fifo #(
		.TCQ(TCQ),
		.WIDTH(1),
		.DEPTH(16),
		.LOG2DEPTH(4)
    ) U_atg_axi_TG_FIFO_WLAST (
	    .clk (i_clk),
		.rst (i_rst),
		.wren (w_last_wfifo_wren),
		.rden (w_last_wfifo_rden),
		.din (w_last_wfifo_din),
		.dout (w_last_wfifo_dout),
		.full (w_last_wfifo_full),
		.empty (w_last_wfifo_empty)
	);

	//AXI ID for AW Channel and W Channel
	always @ ( posedge i_clk or posedge i_rst)
		begin	
			if( i_rst == 1'b1 )
				begin
					r_axi_awid <= #TCQ  {(C_AXI_ID_WIDTH){1'b0}};
					r_axi_wid <= #TCQ  {(C_AXI_ID_WIDTH){1'b0}};
				end
			else
				begin
					//AW Channel ID inc with AW FIFO read en
					if( axi_awvalid && axi_awready )
						begin
							r_axi_awid <= #TCQ  r_axi_awid + {{(C_AXI_ID_WIDTH-1){1'b0}},{1'b1}};
						end
					else
						begin
							r_axi_awid	<= #TCQ  r_axi_awid;
						end
					//W Channel ID inc with AW FIFO read en
					if( w_wrt_wfifo_rden == 1'b1 )
						begin
							r_axi_wid	<= #TCQ  r_axi_wid + {{(C_AXI_ID_WIDTH-1){1'b0}},{1'b1}};
						end
					else
						begin
							r_axi_wid	<= #TCQ  r_axi_wid;
						end
				end
		end
 

endmodule

