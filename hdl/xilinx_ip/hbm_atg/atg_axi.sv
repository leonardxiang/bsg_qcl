`include "defines_h.vh"
`timescale 1ps / 1ps
module atg_axi#(
	parameter SIMULATION		= "TRUE",
	parameter MEM_TYPE			= "DDR4",		// DDR3, DDR4, RLD2, RLD3, QDRIIP, QDRIV
	parameter MEM_ARCH			= "ULTRASCALE", // Memory Architecture: ULTRASCALE, 7SERIES
	parameter APP_DATA_WIDTH	= 256,			// DDR data bus width.
	parameter APP_ADDR_WIDTH	= 29,			// Address bus width of the 
	parameter APP_CMD_WIDTH		= 3,
	parameter DM_WIDTH			= (MEM_TYPE == "RLD3" || MEM_TYPE == "RLD2") ? 18 : 8,
	parameter C_AXI_ID_WIDTH	= 4,
	parameter C_AXI_ADDR_WIDTH	= APP_ADDR_WIDTH, 
	parameter C_AXI_DATA_WIDTH	= APP_DATA_WIDTH,
	parameter TCQ				= 0,		//the axi shim has TCQ=0 
	// Parameter for 2:1 controller in BL8 mode
	parameter nCK_PER_CLK		= 4,
	parameter CMD_PER_CLK		= 1,
	parameter EN_2_1_CONVERTER  = ((MEM_ARCH == "7SERIES") && ((MEM_TYPE == "DDR3") || (MEM_TYPE == "RLD2") || (MEM_TYPE == "RLD3")) && (nCK_PER_CLK == 2) && (CMD_PER_CLK == 1)) ? "TRUE" : "FALSE",
	parameter CMD_PER_CLK_2_1   = (EN_2_1_CONVERTER == "TRUE") ? 1 : CMD_PER_CLK,
	parameter ECC				= "OFF",
	parameter NUM_DQ_PINS		= 32,        // DDR data bus width.
	// Parameter for 2:1 controller in BL8 mode
	parameter APP_DATA_WIDTH_2_1= (EN_2_1_CONVERTER == "TRUE") ? (APP_DATA_WIDTH << 1) : APP_DATA_WIDTH,
	parameter TG_PATTERN_MODE_PRBS_DATA_WIDTH	= 23,
	parameter TG_PATTERN_MODE_PRBS_ADDR_WIDTH	= 23,
  parameter TG_PATTERN_MODE_PRBS_ADDR_SEED = 44'hba987654321,
	parameter TG_INSTR_SM_WIDTH					= 4,
	parameter TG_INSTR_NUM_OF_ITER_WIDTH		= 32,
	parameter DEFAULT_MODE						= "2015_3" // Default model defines default behavior of TG
)(
    input	[TG_PATTERN_MODE_PRBS_ADDR_WIDTH-1:0]	i_TG_PATTERN_MODE_PRBS_ADDR_SEED,
	input							i_clk,
	input							i_rst,
	input							i_init_calib_complete,
	input							vio_tg_rst, // TG reset TG
	input							vio_tg_start, // TG start enable TG
	input							vio_tg_restart, // TG restart
	input							vio_tg_pause, // TG pause (level signal)
	input							vio_tg_err_chk_en, // If Error check is enabled (level signal), 
																  //    TG will stop after first error. 
																  // Else, 
																  //    TG will continue on the rest of the programmed instructions
	input							vio_tg_err_clear, // Clear Error excluding sticky bit (pos edge triggered)
	input							vio_tg_err_clear_all, // Clear Error including sticky bit (pos edge triggered)
	input							vio_tg_err_continue, // Continue run after Error detected (pos edge triggered)
    // TG programming interface
    // - instruction table programming interface
	input							vio_tg_instr_program_en, // VIO to enable instruction programming
	input							vio_tg_direct_instr_en, // VIO to enable direct instruction
	input [4:0]						vio_tg_instr_num, // VIO to program instruction number
	input [3:0]						vio_tg_instr_addr_mode, // VIO to program address mode
	input [3:0]						vio_tg_instr_data_mode, // VIO to program data mode
	input [3:0]						vio_tg_instr_rw_mode, // VIO to program read/write mode
	input [1:0]						vio_tg_instr_rw_submode, // VIO to program read/write submode
	input [2:0]						vio_tg_instr_victim_mode, // VIO to program victim mode
	input [4:0]						vio_tg_instr_victim_aggr_delay, // Define aggressor pattern to be N-clk-delay of victim pattern
	input [2:0]						vio_tg_instr_victim_select, // VIO to program victim mode
	input [TG_INSTR_NUM_OF_ITER_WIDTH-1:0]      vio_tg_instr_num_of_iter, // VIO to program number of iteration per instruction
	input [9:0]						vio_tg_instr_m_nops_btw_n_burst_m, // VIO to program number of NOPs between BURSTs
	input [31:0]					vio_tg_instr_m_nops_btw_n_burst_n, // VIO to program number of BURSTs between NOPs
	input [5:0]						vio_tg_instr_nxt_instr, // VIO to program next instruction pointer
    // TG PRBS Data Seed programming interface
   input							vio_tg_seed_program_en, // VIO to enable prbs data seed programming
   input [7:0]						vio_tg_seed_num, // VIO to program prbs data seed number
   input [TG_PATTERN_MODE_PRBS_DATA_WIDTH-1:0] vio_tg_seed, // VIO to program prbs data seed
    // - global parameter register
   input [7:0]						vio_tg_glb_victim_bit, // Define Victim bit in data pattern
   input [APP_ADDR_WIDTH/CMD_PER_CLK-1:0]      vio_tg_glb_start_addr,
   input [1:0]						vio_tg_glb_qdriv_rw_submode, 
    // - status register
	output							o_wrt_rqt_over_flow,
	output							compare_error,
   output [TG_INSTR_SM_WIDTH-1:0] 	vio_tg_status_state,
   output							vio_tg_status_err_bit_valid, // Intermediate error detected
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_err_bit, // Intermediate error bit pattern
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_exp_bit,
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_read_bit,
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_first_err_bit,
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_first_exp_bit,
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_first_read_bit,
	   output [APP_DATA_WIDTH_2_1-1:0] 	vio_tg_status_err_bit_sticky, // Accumulated error bit pattern
   output [31:0]					vio_tg_status_err_cnt, // immediate error count
   output [APP_ADDR_WIDTH-1:0] 		vio_tg_status_err_addr, // Intermediate error address
   output							vio_tg_status_exp_bit_valid, // immediate expected bit
   output							vio_tg_status_read_bit_valid, // immediate read data bit
   output							vio_tg_status_first_err_bit_valid, // first logged error bit and address
   output [APP_ADDR_WIDTH-1:0] 		vio_tg_status_first_err_addr,
   output							vio_tg_status_first_exp_bit_valid, // first logged error, expected data and address
   output							vio_tg_status_first_read_bit_valid, // first logged error, read data and address
   output							vio_tg_status_err_bit_sticky_valid, // Accumulated error detected
   output [31:0]					vio_tg_status_err_cnt_sticky, // Accumulated error count
   output							vio_tg_status_err_type_valid, // Read/Write error detected
   output							vio_tg_status_err_type, // Read/Write error type
    //output [31:0] 			   vio_tg_status_tot_rd_cnt,
    //output [31:0] 			   vio_tg_status_tot_wr_cnt,
    //output [31:0] 			   vio_tg_status_tot_rd_req_cyc_cnt,
    //output [31:0] 			   vio_tg_status_tot_wr_req_cyc_cnt,
   output							vio_tg_status_wr_done, // In Write Read mode, this signal will be pulsed after every Write/Read cycle
   output							vio_tg_status_done,
   output							vio_tg_status_watch_dog_hang, // Watch dog detected traffic stopped unexpectedly
   output [0:0]						tg_ila_debug, // place holder for ILA
   input							tg_qdriv_submode11_app_rd,
   // AXI INTERFACE Channels
	// AXI write address channel signals
	input										i_m_axi_awready, // Indicates slave is ready to accept a 
	output [C_AXI_ID_WIDTH-1:0]					o_m_axi_awid,    // Write ID
	output [C_AXI_ADDR_WIDTH-1:0]				o_m_axi_awaddr,  // Write address
	output [7:0]								o_m_axi_awlen,   // Write Burst Length
	output [2:0]								o_m_axi_awsize,  // Write Burst size
	output [1:0]								o_m_axi_awburst, // Write Burst type
	output										o_m_axi_awlock,  // Write lock type
	output [3:0]								o_m_axi_awcache, // Write Cache type
	output [2:0]								o_m_axi_awprot,  // Write Protection type
	output										o_m_axi_awvalid, // Write address valid
	// AXI write data channel signals
	input										i_m_axi_wready,  // Write data ready
	`ifdef OPT_DATA_W
		output [C_AXI_DATA_WIDTH*4-1:0]			 o_m_axi_wdata,    // Write data
		output [C_AXI_DATA_WIDTH*4/DM_WIDTH-1:0] o_m_axi_wstrb,    // Write strobes
	`else
		output [C_AXI_DATA_WIDTH-1:0]			 o_m_axi_wdata,    // Write data
		output [C_AXI_DATA_WIDTH/DM_WIDTH-1:0]	 o_m_axi_wstrb,    // Write strobes
	`endif
	output										o_m_axi_wlast,    // Last write transaction   
	output										o_m_axi_wvalid,   // Write valid  
	// AXI write response channel signals
	input  [C_AXI_ID_WIDTH-1:0]					i_m_axi_bid,     // Response ID
	input  [1:0]								i_m_axi_bresp,   // Write response
	input										i_m_axi_bvalid,  // Write reponse valid
	output										o_m_axi_bready,  // Response ready
	// AXI read address channel signals
	input										i_m_axi_arready,     // Read address ready
	output [C_AXI_ID_WIDTH-1:0]					o_m_axi_arid,        // Read ID
	output [C_AXI_ADDR_WIDTH-1:0]				o_m_axi_araddr,      // Read address
	output [7:0]								o_m_axi_arlen,       // Read Burst Length
	output [2:0]								o_m_axi_arsize,      // Read Burst size
	output [1:0]								o_m_axi_arburst,     // Read Burst type
	output										o_m_axi_arlock,      // Read lock type
	output [3:0]								o_m_axi_arcache,     // Read Cache type
	output [2:0]								o_m_axi_arprot,      // Read Protection type
	output										o_m_axi_arvalid,     // Read address valid 
	// AXI read data channel signals   
	input  [C_AXI_ID_WIDTH-1:0]					i_m_axi_rid,     // Response ID
	input  [1:0]								i_m_axi_rresp,   // Read response
	input										i_m_axi_rvalid,  // Read reponse valid
	`ifdef OPT_DATA_W 
		input  [C_AXI_DATA_WIDTH*4-1:0]				i_m_axi_rdata,   // Read data
	`else
		input  [C_AXI_DATA_WIDTH-1:0]				i_m_axi_rdata,   // Read data
	`endif
	input										i_m_axi_rlast,   // Read last
	output										o_m_axi_rready  // Read Response ready
);
	`ifdef OPT_DATA_W
	localparam LP_C_AXI_STRB_4XW			= C_AXI_DATA_WIDTH/DM_WIDTH;
	
	reg  [C_AXI_DATA_WIDTH*4-1:0]			r_m_axi_rdata_256_0;   
	reg  [C_AXI_DATA_WIDTH/2-1:0]			r_m_axi_rdata_128_1;   
	reg  [C_AXI_DATA_WIDTH-1:0]				r_m_axi_rdata_0;   
	reg  [C_AXI_ID_WIDTH-1:0]				r_m_axi_rid_0;     
	reg  [1:0]								r_m_axi_rresp_0;   
	reg										r_m_axi_rvalid_0;  
	reg										r_m_axi_rlast_0;   // Read last
	
	reg  [C_AXI_DATA_WIDTH-1:0]				r_m_axi_rdata_1;   
	reg  [C_AXI_ID_WIDTH-1:0]				r_m_axi_rid_1;     
	reg  [1:0]								r_m_axi_rresp_1;   
	reg										r_m_axi_rvalid_1;  
	reg										r_m_axi_rlast_1;   // Read last
	
	reg  [C_AXI_DATA_WIDTH-1:0]				r_m_axi_rdata;   
	reg  [C_AXI_ID_WIDTH-1:0]				r_m_axi_rid;     
	reg  [1:0]								r_m_axi_rresp;   
	reg										r_m_axi_rvalid;  
	reg										r_m_axi_rlast;   // Read last
	
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_wdata;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_wdata_63_0;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_wdata_127_64;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_wdata_191_128;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_wdata_255_192;    
	wire	[C_AXI_DATA_WIDTH/8-1:0]		w_m_axi_wstrb;    
	wire	[C_AXI_DATA_WIDTH/8-1:0]		w_m_axi_wstrb_63_0;    
	wire	[C_AXI_DATA_WIDTH/8-1:0]		w_m_axi_wstrb_127_64;    
	wire	[C_AXI_DATA_WIDTH/8-1:0]		w_m_axi_wstrb_191_128;    
	wire	[C_AXI_DATA_WIDTH/8-1:0]		w_m_axi_wstrb_255_192;   

	wire  [C_AXI_DATA_WIDTH-1:0]			w_m_axi_rdata;   
	wire  [C_AXI_DATA_WIDTH-1:0]			w_m_axi_rdata_0;   
	wire  [C_AXI_ID_WIDTH-1:0]				w_m_axi_rid;     
	wire  [1:0]								w_m_axi_rresp;   
	wire									w_m_axi_rvalid;  
	wire									w_m_axi_rlast;   // Read last
	wire	[C_AXI_DATA_WIDTH-1:0]			w_m_axi_rdata_xor_0;
	wire	[C_AXI_DATA_WIDTH-1:0]			w_m_axi_rdata_xor_1;
	wire	[C_AXI_DATA_WIDTH-1:0]			w_m_axi_rdata_xor_2;
	wire	[C_AXI_DATA_WIDTH/2-1:0]		w_m_axi_rdata_xor_3;
	wire									w_m_axi_rdata_same;
	
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_rdata_63_0;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_rdata_127_64;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_rdata_191_128;    
	wire [C_AXI_DATA_WIDTH-1:0]				w_m_axi_rdata_255_192;    
	
	
	// WRITE DATA MAPPING
	assign o_m_axi_wdata			= {w_m_axi_wdata_255_192, w_m_axi_wdata_191_128,
									   w_m_axi_wdata_127_64,  w_m_axi_wdata_63_0};   
	
	assign w_m_axi_wdata_63_0		= {w_m_axi_wdata[C_AXI_DATA_WIDTH/2-1:0], w_m_axi_wdata[C_AXI_DATA_WIDTH/2-1:0]};
	assign w_m_axi_wdata_127_64		= {w_m_axi_wdata[C_AXI_DATA_WIDTH-1:C_AXI_DATA_WIDTH/2],w_m_axi_wdata[C_AXI_DATA_WIDTH-1:C_AXI_DATA_WIDTH/2]};
	assign w_m_axi_wdata_191_128	= {w_m_axi_wdata[C_AXI_DATA_WIDTH/2-1:0], w_m_axi_wdata[C_AXI_DATA_WIDTH/2-1:0]};
	assign w_m_axi_wdata_255_192	= {w_m_axi_wdata[C_AXI_DATA_WIDTH-1:C_AXI_DATA_WIDTH/2],w_m_axi_wdata[C_AXI_DATA_WIDTH-1:C_AXI_DATA_WIDTH/2]};


	assign o_m_axi_wstrb			= {w_m_axi_wstrb_255_192, w_m_axi_wstrb_191_128,
									  w_m_axi_wstrb_127_64,w_m_axi_wstrb_63_0};    

	assign w_m_axi_wstrb_63_0		= {w_m_axi_wstrb[LP_C_AXI_STRB_4XW/2-1:0], w_m_axi_wstrb[LP_C_AXI_STRB_4XW/2-1:0]};
	assign w_m_axi_wstrb_127_64		= {w_m_axi_wstrb[LP_C_AXI_STRB_4XW-1:LP_C_AXI_STRB_4XW/2], w_m_axi_wstrb[LP_C_AXI_STRB_4XW-1:LP_C_AXI_STRB_4XW/2]};
	assign w_m_axi_wstrb_191_128	= {w_m_axi_wstrb[LP_C_AXI_STRB_4XW/2-1:0], w_m_axi_wstrb[LP_C_AXI_STRB_4XW/2-1:0]};
	assign w_m_axi_wstrb_255_192	= {w_m_axi_wstrb[LP_C_AXI_STRB_4XW-1:LP_C_AXI_STRB_4XW/2], w_m_axi_wstrb[LP_C_AXI_STRB_4XW-1:LP_C_AXI_STRB_4XW/2]};
	
	
	assign w_m_axi_rdata_0 = w_m_axi_rdata_same ? ~r_m_axi_rdata_1 : r_m_axi_rdata_1;   
	
	assign w_m_axi_rdata_63_0		= {r_m_axi_rdata_256_0[95:64],	 r_m_axi_rdata_256_0[31:0]}; 
	assign w_m_axi_rdata_127_64		= {r_m_axi_rdata_256_0[127:96],  r_m_axi_rdata_256_0[63:32]}; 
	assign w_m_axi_rdata_191_128	= {r_m_axi_rdata_256_0[223:192], r_m_axi_rdata_256_0[159:128]}; 
	assign w_m_axi_rdata_255_192	= {r_m_axi_rdata_256_0[255:224], r_m_axi_rdata_256_0[191:160]}; 

	assign	w_m_axi_rdata_xor_0 =  ~(w_m_axi_rdata_127_64 ^ w_m_axi_rdata_63_0);
	assign	w_m_axi_rdata_xor_1 =  ~(w_m_axi_rdata_255_192 ^ w_m_axi_rdata_191_128);
	assign	w_m_axi_rdata_xor_2 =  ~(w_m_axi_rdata_xor_0 ^ w_m_axi_rdata_xor_1);
	assign	w_m_axi_rdata_xor_3 =  ~(w_m_axi_rdata_xor_2[62:32] ^ w_m_axi_rdata_xor_2[31:0]);
	assign	w_m_axi_rdata_same   = ( & r_m_axi_rdata_128_1); // NUMBER OF LEVELS 5 may be
	
	assign w_m_axi_rdata	= r_m_axi_rdata;   // Read data
	assign  w_m_axi_rid		= r_m_axi_rid;
	assign  w_m_axi_rresp	= r_m_axi_rresp;
	assign	w_m_axi_rvalid	= r_m_axi_rvalid;
	assign w_m_axi_rlast = r_m_axi_rlast;
	always @ ( posedge i_clk or posedge i_rst)
	begin
		if( i_rst == 1'b1 )
			begin
				r_m_axi_rdata_256_0	<= 'd0;  
				r_m_axi_rdata_0		<= 'd0;  
				r_m_axi_rid_0		<= 'd0;  
				r_m_axi_rresp_0		<= 'd0;  
				r_m_axi_rvalid_0	<= 'd0; 
				r_m_axi_rlast_0		<= 1'b0;

				r_m_axi_rdata_128_1	<= 'd0;  
				r_m_axi_rdata_1		<= 'd0;  
				r_m_axi_rid_1		<= 'd0;  
				r_m_axi_rresp_1		<= 'd0;  
				r_m_axi_rvalid_1	<= 'd0; 
				r_m_axi_rlast_1		<= 1'b0;
				
				r_m_axi_rdata		<= 'd0;  
				r_m_axi_rid			<= 'd0;  
				r_m_axi_rresp		<= 'd0;  
				r_m_axi_rvalid		<= 'd0; 
				r_m_axi_rlast		<= 1'b0;
			end
		else
			begin
				r_m_axi_rdata_256_0		<= i_m_axi_rdata;  
				//r_m_axi_rdata_0		<= i_m_axi_rdata[63:0];  
				r_m_axi_rdata_0			<= {i_m_axi_rdata[95:64], i_m_axi_rdata[31:0]};  
				r_m_axi_rid_0			<= i_m_axi_rid;  
				r_m_axi_rresp_0			<= i_m_axi_rresp;  
				r_m_axi_rvalid_0		<= i_m_axi_rvalid;
				r_m_axi_rlast_0			<= i_m_axi_rlast;

				r_m_axi_rdata_128_1		<= {w_m_axi_rdata_xor_3};  
				r_m_axi_rdata_1			<= r_m_axi_rdata_0;  
				r_m_axi_rid_1			<= r_m_axi_rid_0;  
				r_m_axi_rresp_1			<= r_m_axi_rresp_0;  
				r_m_axi_rvalid_1		<= r_m_axi_rvalid_0; 
				r_m_axi_rlast_1			<= r_m_axi_rlast_0;
				
				r_m_axi_rdata			<= w_m_axi_rdata_0;  
				r_m_axi_rid				<= r_m_axi_rid;  
				r_m_axi_rresp			<= r_m_axi_rresp_1;  
				r_m_axi_rvalid			<= r_m_axi_rvalid_1; 
				r_m_axi_rlast			<= r_m_axi_rlast_1;

			end
	end

	`endif



	// Wire Declaration 
	wire [APP_ADDR_WIDTH-1:0]       w_app_addr;
	wire [C_AXI_ADDR_WIDTH-1:0]     w_app2axi_addr = {w_app_addr, 2'h0}; // APP to AXI Address conversion
   wire [2:0]						w_app_cmd;
   wire								w_app_en;
   wire [APP_DATA_WIDTH-1:0]        w_app_wdf_data;
   wire								w_app_wdf_end;
   wire [(APP_DATA_WIDTH/DM_WIDTH)-1:0]        w_app_wdf_mask;
   wire								w_app_wdf_wren;
   wire [APP_DATA_WIDTH-1:0]        w_app_rd_data;
   wire								w_app_rd_data_end;
   wire								w_app_rd_data_valid;
   wire								w_app_rdy;
   wire								w_app_wdf_rdy;
   
   (* KEEP = "TRUE" *) reg          i_rst_r1_hw_tg;
   (* KEEP = "TRUE" *) reg          i_rst_r1_app2axi;

   always @(posedge i_clk)
   begin
     i_rst_r1_hw_tg <= i_rst;
     i_rst_r1_app2axi <= i_rst;
   end	

	// ATG INSTANSIATION
	atg_axi_hw_tg #(
       .SIMULATION      (SIMULATION),
       .MEM_TYPE        (MEM_TYPE),
       .APP_DATA_WIDTH  (APP_DATA_WIDTH),
       .APP_ADDR_WIDTH  (APP_ADDR_WIDTH),
       .NUM_DQ_PINS     (NUM_DQ_PINS),
       .ECC             (ECC),
	   .TCQ				(TCQ),
       .DEFAULT_MODE    (DEFAULT_MODE),
		.MEM_ARCH(MEM_ARCH), 
		.APP_CMD_WIDTH(APP_CMD_WIDTH),
		.nCK_PER_CLK(nCK_PER_CLK),
		.CMD_PER_CLK(CMD_PER_CLK),
		.TG_PATTERN_MODE_PRBS_DATA_WIDTH(TG_PATTERN_MODE_PRBS_DATA_WIDTH),
	    .TG_PATTERN_MODE_PRBS_ADDR_WIDTH(TG_PATTERN_MODE_PRBS_ADDR_WIDTH ), 
        .TG_PATTERN_MODE_PRBS_ADDR_SEED (TG_PATTERN_MODE_PRBS_ADDR_SEED),
		.TG_INSTR_SM_WIDTH(TG_INSTR_SM_WIDTH),
		.TG_INSTR_NUM_OF_ITER_WIDTH(TG_INSTR_NUM_OF_ITER_WIDTH)
    ) INST_HW_TG(
		.i_TG_PATTERN_MODE_PRBS_ADDR_SEED(i_TG_PATTERN_MODE_PRBS_ADDR_SEED),
         .clk                  (i_clk),
         .rst                  (i_rst_r1_hw_tg),
         .init_calib_complete  (i_init_calib_complete),
         // APP I/F 
		 .app_rdy              (w_app_rdy),
         .app_wdf_rdy          (w_app_wdf_rdy),
         .app_rd_data_valid    (w_app_rd_data_valid),
         .app_rd_data          (w_app_rd_data),
         .app_cmd              (w_app_cmd),
         .app_addr             (w_app_addr),
         .app_en               (w_app_en),
         .app_wdf_mask         (w_app_wdf_mask),
         .app_wdf_data         (w_app_wdf_data),
         .app_wdf_end          (w_app_wdf_end),
         .app_wdf_wren         (w_app_wdf_wren),
         .app_wdf_en           (), // valid for QDRII+ only
         .app_wdf_addr         (), // valid for QDRII+ only
         .app_wdf_cmd          (), // valid for QDRII+ only
		 //VIO control
         .compare_error						   (compare_error),
         .vio_tg_rst                           (vio_tg_rst),
         .vio_tg_start                         (vio_tg_start),
         .vio_tg_err_chk_en                    (vio_tg_err_chk_en),
         .vio_tg_err_clear                     (vio_tg_err_clear),
         .vio_tg_instr_addr_mode               (vio_tg_instr_addr_mode),
         .vio_tg_instr_data_mode               (vio_tg_instr_data_mode),
         .vio_tg_instr_rw_mode                 (vio_tg_instr_rw_mode),
         .vio_tg_instr_rw_submode              (vio_tg_instr_rw_submode),
         .vio_tg_instr_num_of_iter             (vio_tg_instr_num_of_iter),
         .vio_tg_instr_nxt_instr               (vio_tg_instr_nxt_instr),
         .vio_tg_restart                       (vio_tg_restart),
         .vio_tg_pause                         (vio_tg_pause),
         .vio_tg_err_clear_all                 (vio_tg_err_clear_all),
         .vio_tg_err_continue                  (vio_tg_err_continue),
         .vio_tg_instr_program_en              (vio_tg_instr_program_en),
         .vio_tg_direct_instr_en               (vio_tg_direct_instr_en),
         .vio_tg_instr_num                     (vio_tg_instr_num),
         .vio_tg_instr_victim_mode             (vio_tg_instr_victim_mode),
         .vio_tg_instr_victim_aggr_delay       (vio_tg_instr_victim_aggr_delay),
         .vio_tg_instr_victim_select           (vio_tg_instr_victim_select),
         .vio_tg_instr_m_nops_btw_n_burst_m    (vio_tg_instr_m_nops_btw_n_burst_m),
         .vio_tg_instr_m_nops_btw_n_burst_n    (vio_tg_instr_m_nops_btw_n_burst_n),
         .vio_tg_seed_program_en               (vio_tg_seed_program_en),
         .vio_tg_seed_num                      (vio_tg_seed_num),
         .vio_tg_seed                          (vio_tg_seed),
         .vio_tg_glb_victim_bit                (vio_tg_glb_victim_bit),
         .vio_tg_glb_start_addr                (vio_tg_glb_start_addr),
         .vio_tg_glb_qdriv_rw_submode          (2'b00),
         // VI status
		 .vio_tg_status_state                  (vio_tg_status_state),
         .vio_tg_status_err_bit_valid          (vio_tg_status_err_bit_valid),
			 .vio_tg_status_err_bit                (vio_tg_status_err_bit),
			 .vio_tg_status_exp_bit                (vio_tg_status_exp_bit),
			 .vio_tg_status_read_bit               (vio_tg_status_read_bit),
			 .vio_tg_status_first_err_bit          (vio_tg_status_first_err_bit),
			 .vio_tg_status_first_exp_bit          (vio_tg_status_first_exp_bit),
			 .vio_tg_status_first_read_bit         (vio_tg_status_first_read_bit),
			 .vio_tg_status_err_bit_sticky         (vio_tg_status_err_bit_sticky),
         .vio_tg_status_err_cnt                (vio_tg_status_err_cnt),
         .vio_tg_status_err_addr               (vio_tg_status_err_addr),
         .vio_tg_status_exp_bit_valid          (vio_tg_status_exp_bit_valid),
         .vio_tg_status_read_bit_valid         (vio_tg_status_read_bit_valid),
         .vio_tg_status_first_err_bit_valid    (vio_tg_status_first_err_bit_valid),
         .vio_tg_status_first_err_addr         (vio_tg_status_first_err_addr),
         .vio_tg_status_first_exp_bit_valid    (vio_tg_status_first_exp_bit_valid),
         .vio_tg_status_first_read_bit_valid   (vio_tg_status_first_read_bit_valid),
         .vio_tg_status_err_bit_sticky_valid   (vio_tg_status_err_bit_sticky_valid),
         .vio_tg_status_err_cnt_sticky         (vio_tg_status_err_cnt_sticky),
         .vio_tg_status_err_type_valid         (vio_tg_status_err_type_valid),
         .vio_tg_status_err_type               (vio_tg_status_err_type),
         .vio_tg_status_wr_done                (vio_tg_status_wr_done),
         .vio_tg_status_done                   (vio_tg_status_done),
         .vio_tg_status_watch_dog_hang         (vio_tg_status_watch_dog_hang),
         .tg_ila_debug                         (tg_ila_debug),
         .tg_qdriv_submode11_app_rd            (1'b0)
  );

  // APP2AXI conversion module

 // app2axi conversion logic
	app2axi # 
	   (
		.C_AXI_ID_WIDTH		(C_AXI_ID_WIDTH),
		.C_AXI_ADDR_WIDTH	(APP_ADDR_WIDTH),
		.C_AXI_DATA_WIDTH	(APP_DATA_WIDTH),
       .APP_DATA_WIDTH		(APP_DATA_WIDTH),
       .APP_ADDR_WIDTH		(APP_ADDR_WIDTH),
	   .APP_CMD_WIDTH		(APP_CMD_WIDTH)
	) INST_APP2AXI(
       .i_clk                                   (i_clk),
       .i_rst                                   (i_rst_r1_app2axi),
	   .o_wrt_rqt_over_flow						(o_wrt_rqt_over_flow),
       .app_rdy                                 (w_app_rdy),
       .app_rd_data_valid                       (w_app_rd_data_valid),
       .app_rd_data                             (w_app_rd_data),
       .app_wdf_rdy                             (w_app_wdf_rdy),
       .app_en                                  (w_app_en),
       .app_cmd                                 (w_app_cmd),
       .app_addr                                (w_app2axi_addr), // (w_app_addr),
       .app_wdf_wren                            (w_app_wdf_wren),
       .app_wdf_end                             (w_app_wdf_end),
       .app_wdf_mask                            (w_app_wdf_mask),
       .app_wdf_data                            (w_app_wdf_data),
       .app_wdf_en                              (1'b0), // valid for QDRII+ only
       .app_wdf_addr                            (33'b0), // valid for QDRII+ only
       .app_wdf_cmd                             (3'b0), // valid for QDRII+ only
         // Slave Interface Write Address Ports
      .axi_awready                     (i_m_axi_awready),
      .axi_awid                        (o_m_axi_awid),
      .axi_awaddr                      (o_m_axi_awaddr),
      .axi_awlen                       (o_m_axi_awlen),
      .axi_awsize                      (o_m_axi_awsize),
      .axi_awburst                     (o_m_axi_awburst),
      .axi_awlock                      (o_m_axi_awlock),
      .axi_awcache                     (o_m_axi_awcache),
      .axi_awprot                      (o_m_axi_awprot),
      .axi_awvalid                     (o_m_axi_awvalid),
      // Slave Interface Write Data Ports
      .axi_wready                      (i_m_axi_wready),
	`ifdef OPT_DATA_W
      .axi_wdata                       (w_m_axi_wdata),
      .axi_wstrb                       (w_m_axi_wstrb),
	`else
      .axi_wdata                       (o_m_axi_wdata),
      .axi_wstrb                       (o_m_axi_wstrb),
	`endif
      .axi_wlast                       (o_m_axi_wlast),
      .axi_wvalid                      (o_m_axi_wvalid),
      // Slave Interface Write Response Ports
      .axi_bid                         (i_m_axi_bid),
      .axi_bresp                       (i_m_axi_bresp),
      .axi_bvalid                      (i_m_axi_bvalid),
      .axi_bready                      (o_m_axi_bready),
      // Slave Interface Read Address Ports
      .axi_arready                     (i_m_axi_arready),
      .axi_arid                        (o_m_axi_arid),
      .axi_araddr                      (o_m_axi_araddr),
      .axi_arlen                       (o_m_axi_arlen),
      .axi_arsize                      (o_m_axi_arsize),
      .axi_arburst                     (o_m_axi_arburst),
      .axi_arlock                      (o_m_axi_arlock),
      .axi_arcache                     (o_m_axi_arcache),
      .axi_arprot                      (o_m_axi_arprot),
      .axi_arvalid                     (o_m_axi_arvalid),
      // Slave Interface Read Data Ports
	 `ifdef OPT_DATA_W 
      .axi_rid                         (w_m_axi_rid),
      .axi_rresp                       (w_m_axi_rresp),
      .axi_rvalid                      (w_m_axi_rvalid),
      .axi_rdata                       (w_m_axi_rdata),
      .axi_rlast                       (w_m_axi_rlast),
	 `else
      .axi_rid                         (i_m_axi_rid),
      .axi_rresp                       (i_m_axi_rresp),
      .axi_rvalid                      (i_m_axi_rvalid),
      .axi_rdata                       (i_m_axi_rdata),
      .axi_rlast                       (i_m_axi_rlast),
	  `endif
      .axi_rready                      (o_m_axi_rready)
    );

endmodule
