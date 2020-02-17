/*
* hbm_manycore_top.v
*
* top level of the F1_manycore design on local FPGA
*/

`include "hbm_manycore.vh"

module hbm_manycore_top
  import bsg_fpga_board_pkg::*;
  import cl_manycore_pkg::*;
  import bsg_bladerunner_mem_cfg_pkg::*;
#(
  parameter pcie_width_p = 4
  ,parameter pcie_speed_p = 1
  ,parameter pcie_axi_id_width_p = 4
  ,parameter pcie_axi_data_width_p = 64
  ,parameter pcie_axi_addr_width_p = 64
  ,parameter APP_DATA_WIDTH   = 256
  ,parameter APP_ADDR_WIDTH = 33
  ,parameter num_hbm_chs_lp = 16
  ,localparam hbm_data_width_lp = 256
  ,localparam num_max_hbm_chs_lp = 16
  `ifdef SIMULATION_MODE
  ,parameter SIMULATION     = "TRUE"
  `else
  ,parameter SIMULATION     = "FALSE"
  `endif
) (
  input                     pcie_clk_i_p
  ,input                     pcie_clk_i_n
  ,input                     pcie_resetn_i
  ,input                     ext_btn_reset_i
  ,input                     mem_clk_i_p
  ,input                     mem_clk_i_n
  ,input  [pcie_width_p-1:0] pcie_i_p
  ,input  [pcie_width_p-1:0] pcie_i_n
  ,output [pcie_width_p-1:0] pcie_o_p
  ,output [pcie_width_p-1:0] pcie_o_n
  ,output [             7:0] leds_o
);

`ifdef OPT_DATA_W
  localparam APP_DATA_WIDTH_4D = APP_DATA_WIDTH/4;
`else
  localparam APP_DATA_WIDTH_4D = APP_DATA_WIDTH;
`endif

  `include "bsg_axi_bus_pkg.vh"

  `declare_bsg_axi4_bus_s(1,pcie_axi_id_width_p,pcie_axi_addr_width_p,pcie_axi_data_width_p,bsg_axi4_pcie_mosi_s,bsg_axi4_pcie_miso_s);

  `declare_bsg_axi4_bus_s(1,axi_id_width_p,axi_addr_width_p,axi_data_width_p,bsg_axi4_mosi_bus_s,bsg_axi4_miso_bus_s);

  `declare_bsg_axi4_bus_s(1,axi_id_width_p,axi_addr_width_p,hbm_data_width_lp,bsg_axi4_hbm_si_s,bsg_axi4_hbm_mo_s);

  bsg_axi4_mosi_bus_s s_axi4_bram_li;
  bsg_axi4_miso_bus_s s_axi4_bram_lo;

  bsg_axi4_hbm_si_s [num_hbm_chs_lp-1:0] axi4_hbm_chs_li;
  bsg_axi4_hbm_mo_s [num_hbm_chs_lp-1:0] axi4_hbm_chs_lo;


  // ---------------------------------------------
  // CLOCKs
  // ---------------------------------------------

  localparam lc_core_mem_clk_period_p = 8000;  // 125
  localparam lc_hbm_axi_clk_period_p  = 4000;  // 250

  // pcie user clock
  wire clk_axi4_pcie_li;

  // internal pll
  wire [2:0] locked_pll;

  (* keep = "TRUE" *) wire APB_0_PCLK_IBUF;
  (* keep = "TRUE" *) wire AXI_ACLK_IN_0_buf;
  (* keep = "TRUE" *) wire HBM_REF_CLK_0;

  wire hbm_axil_clk_int ;
  wire hbm_ref_clk_int;
  clk_wiz_0 mem_global_pll (
    // Clock out ports
    .clk_out1 (APB_0_PCLK_IBUF ),  // 100
    .clk_out2 (hbm_axil_clk_int),  // 100
    .clk_out3 (hbm_ref_clk_int ),  // 100
    // Status and control signals
    .reset    (1'b0            ),
    .locked   (locked_pll[0]   ),
    // Clock in ports
    .clk_in1_p(mem_clk_i_p     ),  // 100
    .clk_in1_n(mem_clk_i_n     )
  );

  clk_wiz_1 hbm_axi_pll (
    // Clock out ports
    .clk_out1(AXI_ACLK_IN_0_buf),
    // Status and control signals
    .reset   (1'b0             ),
    .locked  (locked_pll[2]    ),
    // Clock in ports
    .clk_in1 (hbm_axil_clk_int )
  );

  clk_wiz_1 hbm_ref_pll (
    // Clock out ports
    .clk_out1(HBM_REF_CLK_0  ),
    // Status and control signals
    .reset   (1'b0           ),
    .locked  (locked_pll[1]  ),
    // Clock in ports
    .clk_in1 (hbm_ref_clk_int)
  );

////////////////////////////////////////////////////////////////////////////////
// Localparams
////////////////////////////////////////////////////////////////////////////////
  localparam MMCM_CLKFBOUT_MULT_F  = 70;
  localparam MMCM_CLKOUT0_DIVIDE_F = 4;
  localparam MMCM_DIVCLK_DIVIDE    = 7;
  localparam MMCM_CLKIN1_PERIOD    = 10.000;

  localparam MMCM1_CLKFBOUT_MULT_F  = 18;
  localparam MMCM1_CLKOUT0_DIVIDE_F = 2;
  localparam MMCM1_DIVCLK_DIVIDE    = 2;
  localparam MMCM1_CLKIN1_PERIOD    = 10.000;

////////////////////////////////////////////////////////////////////////////////
// Wire Delcaration
////////////////////////////////////////////////////////////////////////////////
// (* keep = "TRUE" *)   wire          AXI_ACLK_IN_0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK_IN_0_iobuf;
  (* keep = "TRUE" *)   wire          AXI_ACLK0_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK1_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK2_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK3_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK4_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK5_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK6_st0;
  (* keep = "TRUE" *)   wire          AXI_ACLK0_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK1_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK2_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK3_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK4_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK5_st0_buf;
  (* keep = "TRUE" *)   wire          AXI_ACLK6_st0_buf;
  (* keep = "TRUE" *)  wire          i_clk_atg_axi_vio_st0;
  wire          MMCM_LOCK_0;
reg           axi_rst_0_mmcm_n_0;

////////////////////////////////////////////////////////////////////////////////
// Instantiating MMCM for AXI clock generation
////////////////////////////////////////////////////////////////////////////////
MMCME4_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("INTERNAL"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (MMCM_DIVCLK_DIVIDE),
    .CLKFBOUT_MULT_F      (MMCM_CLKFBOUT_MULT_F),
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT2_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT3_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT4_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT5_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKOUT6_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
    .CLKIN1_PERIOD        (MMCM_CLKIN1_PERIOD),
    .REF_JITTER1          (0.010))
  u_mmcm_0
    // Output clocks
   (
    .CLKFBOUT            (),
    .CLKFBOUTB           (),
    .CLKOUT0             (AXI_ACLK0_st0),

    .CLKOUT0B            (),
    .CLKOUT1             (AXI_ACLK1_st0),
    .CLKOUT1B            (),
    .CLKOUT2             (AXI_ACLK2_st0),
    .CLKOUT2B            (),
    .CLKOUT3             (AXI_ACLK3_st0),
    .CLKOUT3B            (),
    .CLKOUT4             (AXI_ACLK4_st0),
    .CLKOUT5             (AXI_ACLK5_st0),
    .CLKOUT6             (AXI_ACLK6_st0),
     // Input clock control
    .CLKFBIN             (), //mmcm_fb
    .CLKIN1              (AXI_ACLK_IN_0_buf),
    .CLKIN2              (1'b0),
    // Other control and status signals
    .LOCKED              (MMCM_LOCK_0),
    .PWRDWN              (1'b0),
    .RST                 (~axi_rst_0_mmcm_n_0),

    .CDDCDONE            (),
    .CLKFBSTOPPED        (),
    .CLKINSTOPPED        (),
    .DO                  (),
    .DRDY                (),
    .PSDONE              (),
    .CDDCREQ             (1'b0),
    .CLKINSEL            (1'b1),
    .DADDR               (7'b0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'b0),
    .DWE                 (1'b0),
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0)
  );

BUFG u_AXI_ACLK0_st0  (
  .I (AXI_ACLK0_st0),
  .O (AXI_ACLK0_st0_buf)
);

BUFG u_AXI_ACLK1_st0  (
  .I (AXI_ACLK1_st0),
  .O (AXI_ACLK1_st0_buf)
);

BUFG u_AXI_ACLK2_st0  (
  .I (AXI_ACLK2_st0),
  .O (AXI_ACLK2_st0_buf)
);

BUFG u_AXI_ACLK3_st0  (
  .I (AXI_ACLK3_st0),
  .O (AXI_ACLK3_st0_buf)
);

BUFG u_AXI_ACLK4_st0  (
  .I (AXI_ACLK4_st0),
  .O (AXI_ACLK4_st0_buf)
);

BUFG u_AXI_ACLK5_st0  (
  .I (AXI_ACLK5_st0),
  .O (AXI_ACLK5_st0_buf)
);

BUFG u_AXI_ACLK6_st0  (
  .I (AXI_ACLK6_st0),
  .O (AXI_ACLK6_st0_buf)
);

BUFGCE_DIV #(.BUFGCE_DIVIDE(2)) u_AXI_vio_CLK_st0 (
  .I  (AXI_ACLK0_st0        ),
  .CE (1'b1                 ),
  .CLR(1'b0                 ),
  .O  (i_clk_atg_axi_vio_st0)
);


// ---------------------------------------------
// RESETS
// ---------------------------------------------
  // PCIe
  wire rstn_axi4_pcie_li;

  // external
  logic ext_reset_dbnc;
  qcl_debounce #(.els_p(22)) reset_debounce (
    .clk_i(clk_axi4_pcie_li),
    .i    (ext_btn_reset_i),
    .o    (ext_reset_dbnc )
  );

  // manycore reset
  // TODO: add system hard reset
  wire mc_reset_i = (ext_reset_dbnc  | ~rstn_axi4_pcie_li);

  // ---------------------------------------------
  // PCIe endpoint
  // ---------------------------------------------

  wire [31:0] m_axil_awaddr;
  wire m_axil_awvalid;
  wire m_axil_awready;
  wire [31:0] m_axil_wdata;
  wire [3:0] m_axil_wstrb;
  wire m_axil_wvalid;
  wire m_axil_wready;
  wire [1:0] m_axil_bresp;
  wire m_axil_bvalid;
  wire m_axil_bready;
  wire [31:0] m_axil_araddr;
  wire m_axil_arvalid;
  wire m_axil_arready;
  wire [31:0] m_axil_rdata;
  wire [1:0] m_axil_rresp;
  wire m_axil_rvalid;
  wire m_axil_rready;

  wire [3:0] m_axi_awid;
  wire [63:0] m_axi_awaddr;
  wire [7:0] m_axi_awlen;
  wire [2:0] m_axi_awsize;
  wire [1:0] m_axi_awburst;
  wire m_axi_awvalid;
  wire m_axi_awready;
  wire [pcie_axi_data_width_p-1:0] m_axi_wdata;
  wire [(pcie_axi_data_width_p/8)-1:0] m_axi_wstrb;
  wire m_axi_wlast;
  wire m_axi_wvalid;
  wire m_axi_wready;
  wire [3:0] m_axi_bid;
  wire [1:0] m_axi_bresp;
  wire m_axi_bvalid;
  wire m_axi_bready;
  wire [3:0] m_axi_arid;
  wire [63:0] m_axi_araddr;
  wire [7:0] m_axi_arlen;
  wire [2:0] m_axi_arsize;
  wire [1:0] m_axi_arburst;
  wire m_axi_arvalid;
  wire m_axi_arready;
  wire [3:0] m_axi_rid;
  wire [pcie_axi_data_width_p-1:0] m_axi_rdata;
  wire [1:0] m_axi_rresp;
  wire m_axi_rlast;
  wire m_axi_rvalid;
  wire m_axi_rready;

  wire [3:0] m_axib_awid;
  wire [63:0] m_axib_awaddr;
  wire [7:0] m_axib_awlen;
  wire [2:0] m_axib_awsize;
  wire [1:0] m_axib_awburst;
  wire m_axib_awvalid;
  wire m_axib_awready;
  wire [pcie_axi_data_width_p-1:0] m_axib_wdata;
  wire [(pcie_axi_data_width_p/8)-1:0] m_axib_wstrb;
  wire m_axib_wlast;
  wire m_axib_wvalid;
  wire m_axib_wready;
  wire [3:0] m_axib_bid;
  wire [1:0] m_axib_bresp;
  wire m_axib_bvalid;
  wire m_axib_bready;
  wire [3:0] m_axib_arid;
  wire [63:0] m_axib_araddr;
  wire [7:0] m_axib_arlen;
  wire [2:0] m_axib_arsize;
  wire [1:0] m_axib_arburst;
  wire m_axib_arvalid;
  wire m_axib_arready;
  wire [3:0] m_axib_rid;
  wire [pcie_axi_data_width_p-1:0] m_axib_rdata;
  wire [1:0] m_axib_rresp;
  wire m_axib_rlast;
  wire m_axib_rvalid;
  wire m_axib_rready;

  wire user_link_up_lo;
  wire sys_rst_n_buf_lo;

  xilinx_dma_pcie_ep #(
    .PL_LINK_CAP_MAX_LINK_WIDTH(pcie_width_p         ),
    .PL_LINK_CAP_MAX_LINK_SPEED(pcie_speed_p         ),
    .C_DATA_WIDTH              (pcie_axi_data_width_p),
    .C_M_AXI_ID_WIDTH          (pcie_axi_id_width_p  ),
    .C_M_AXI_ADDR_WIDTH        (pcie_axi_addr_width_p)
  ) xdma_inst (
    .pci_exp_txp    (pcie_o_p        ),
    .pci_exp_txn    (pcie_o_n        ),
    .pci_exp_rxp    (pcie_i_p        ),
    .pci_exp_rxn    (pcie_i_n        ),
    .sys_clk_p_i    (pcie_clk_i_p    ),
    .sys_clk_n_i    (pcie_clk_i_n    ),
    .sys_rst_n_i    (pcie_resetn_i   ),
    .sys_rst_n_buf_o(sys_rst_n_buf_lo),
    .user_clk_o     (clk_axi4_pcie_li ),
    .user_resetn_o  (rstn_axi4_pcie_li),
    .user_link_up_o (user_link_up_lo ),
    // AXIL
    .m_axil_awaddr  (m_axil_awaddr   ),
    .m_axil_awvalid (m_axil_awvalid  ),
    .m_axil_awready (m_axil_awready  ),
    .m_axil_wdata   (m_axil_wdata    ),
    .m_axil_wstrb   (m_axil_wstrb    ),
    .m_axil_wvalid  (m_axil_wvalid   ),
    .m_axil_wready  (m_axil_wready   ),
    .m_axil_bresp   (m_axil_bresp    ),
    .m_axil_bvalid  (m_axil_bvalid   ),
    .m_axil_bready  (m_axil_bready   ),
    .m_axil_araddr  (m_axil_araddr   ),
    .m_axil_arvalid (m_axil_arvalid  ),
    .m_axil_arready (m_axil_arready  ),
    .m_axil_rdata   (m_axil_rdata    ),
    .m_axil_rresp   (m_axil_rresp    ),
    .m_axil_rvalid  (m_axil_rvalid   ),
    .m_axil_rready  (m_axil_rready   ),
    // AXI4 dma
    .m_axi_awid     (m_axi_awid      ),
    .m_axi_awaddr   (m_axi_awaddr    ),
    .m_axi_awlen    (m_axi_awlen     ),
    .m_axi_awsize   (m_axi_awsize    ),
    .m_axi_awburst  (m_axi_awburst   ),
    .m_axi_awvalid  (m_axi_awvalid   ),
    .m_axi_awready  (m_axi_awready   ),
    .m_axi_wdata    (m_axi_wdata     ),
    .m_axi_wstrb    (m_axi_wstrb     ),
    .m_axi_wlast    (m_axi_wlast     ),
    .m_axi_wvalid   (m_axi_wvalid    ),
    .m_axi_wready   (m_axi_wready    ),
    .m_axi_bid      (m_axi_bid       ),
    .m_axi_bresp    (m_axi_bresp     ),
    .m_axi_bvalid   (m_axi_bvalid    ),
    .m_axi_bready   (m_axi_bready    ),
    .m_axi_arid     (m_axi_arid      ),
    .m_axi_araddr   (m_axi_araddr    ),
    .m_axi_arlen    (m_axi_arlen     ),
    .m_axi_arsize   (m_axi_arsize    ),
    .m_axi_arburst  (m_axi_arburst   ),
    .m_axi_arvalid  (m_axi_arvalid   ),
    .m_axi_arready  (m_axi_arready   ),
    .m_axi_rid      (m_axi_rid       ),
    .m_axi_rdata    (m_axi_rdata     ),
    .m_axi_rresp    (m_axi_rresp     ),
    .m_axi_rlast    (m_axi_rlast     ),
    .m_axi_rvalid   (m_axi_rvalid    ),
    .m_axi_rready   (m_axi_rready    ),
    // AXI4 Bypass
    .m_axib_awid    (m_axib_awid     ),
    .m_axib_awaddr  (m_axib_awaddr   ),
    .m_axib_awlen   (m_axib_awlen    ),
    .m_axib_awsize  (m_axib_awsize   ),
    .m_axib_awburst (m_axib_awburst  ),
    .m_axib_awvalid (m_axib_awvalid  ),
    .m_axib_awready (m_axib_awready  ),
    .m_axib_wdata   (m_axib_wdata    ),
    .m_axib_wstrb   (m_axib_wstrb    ),
    .m_axib_wlast   (m_axib_wlast    ),
    .m_axib_wvalid  (m_axib_wvalid   ),
    .m_axib_wready  (m_axib_wready   ),
    .m_axib_bid     (m_axib_bid      ),
    .m_axib_bresp   (m_axib_bresp    ),
    .m_axib_bvalid  (m_axib_bvalid   ),
    .m_axib_bready  (m_axib_bready   ),
    .m_axib_arid    (m_axib_arid     ),
    .m_axib_araddr  (m_axib_araddr   ),
    .m_axib_arlen   (m_axib_arlen    ),
    .m_axib_arsize  (m_axib_arsize   ),
    .m_axib_arburst (m_axib_arburst  ),
    .m_axib_arvalid (m_axib_arvalid  ),
    .m_axib_arready (m_axib_arready  ),
    .m_axib_rid     (m_axib_rid      ),
    .m_axib_rdata   (m_axib_rdata    ),
    .m_axib_rresp   (m_axib_rresp    ),
    .m_axib_rlast   (m_axib_rlast    ),
    .m_axib_rvalid  (m_axib_rvalid   ),
    .m_axib_rready  (m_axib_rready   )
  );

  // User Clock LED Heartbeat
  localparam TCQ                = 1;
  reg [26:0] user_clk_heartbeat    ;
  // Create a Clock Heartbeat
  always_ff @(posedge clk_axi4_pcie_li) begin
    if(!sys_rst_n_buf_lo) begin
      user_clk_heartbeat <= #TCQ 27'd0;
    end else begin
      user_clk_heartbeat <= #TCQ user_clk_heartbeat + 1'b1;
    end
  end

  // 1st AXI interface, axil ocl interface
  // ---------------------------------------------

  `declare_bsg_axil_bus_s(1, bsg_axil_mosi_bus_s, bsg_axil_miso_bus_s);
   bsg_axil_mosi_bus_s s_axil_ocl_li;
   bsg_axil_miso_bus_s s_axil_ocl_lo;

  assign s_axil_ocl_li.awaddr  = m_axil_awaddr;
  assign s_axil_ocl_li.awvalid = m_axil_awvalid;
  assign s_axil_ocl_li.wdata   = m_axil_wdata;
  assign s_axil_ocl_li.wstrb   = m_axil_wstrb;
  assign s_axil_ocl_li.wvalid  = m_axil_wvalid;
  assign s_axil_ocl_li.bready  = m_axil_bready;
  assign s_axil_ocl_li.araddr  = m_axil_araddr;
  assign s_axil_ocl_li.arvalid = m_axil_arvalid;
  assign s_axil_ocl_li.rready  = m_axil_rready;

  assign m_axil_awready = s_axil_ocl_lo.awready;
  assign m_axil_wready  = s_axil_ocl_lo.wready;
  assign m_axil_bresp   = s_axil_ocl_lo.bresp;
  assign m_axil_bvalid  = s_axil_ocl_lo.bvalid;
  assign m_axil_arready = s_axil_ocl_lo.arready;
  assign m_axil_rdata   = s_axil_ocl_lo.rdata;
  assign m_axil_rresp   = s_axil_ocl_lo.rresp;
  assign m_axil_rvalid  = s_axil_ocl_lo.rvalid;


  // 2nd AXI interface, for DMA testing
  // --------------------------------------------

  blk_mem_gen_1 blk_mem_xdma_inst (
    .s_aclk       (clk_axi4_pcie_li   ),
    .s_aresetn    (rstn_axi4_pcie_li  ),
    .s_axi_awid   (m_axi_awid        ),
    .s_axi_awaddr (m_axi_awaddr[31:0]),
    .s_axi_awlen  (m_axi_awlen       ),
    .s_axi_awsize (m_axi_awsize      ),
    .s_axi_awburst(m_axi_awburst     ),
    .s_axi_awvalid(m_axi_awvalid     ),
    .s_axi_awready(m_axi_awready     ),
    .s_axi_wdata  (m_axi_wdata       ),
    .s_axi_wstrb  (m_axi_wstrb       ),
    .s_axi_wlast  (m_axi_wlast       ),
    .s_axi_wvalid (m_axi_wvalid      ),
    .s_axi_wready (m_axi_wready      ),
    .s_axi_bid    (m_axi_bid         ),
    .s_axi_bresp  (m_axi_bresp       ),
    .s_axi_bvalid (m_axi_bvalid      ),
    .s_axi_bready (m_axi_bready      ),
    .s_axi_arid   (m_axi_arid        ),
    .s_axi_araddr (m_axi_araddr[31:0]),
    .s_axi_arlen  (m_axi_arlen       ),
    .s_axi_arsize (m_axi_arsize      ),
    .s_axi_arburst(m_axi_arburst     ),
    .s_axi_arvalid(m_axi_arvalid     ),
    .s_axi_arready(m_axi_arready     ),
    .s_axi_rid    (m_axi_rid         ),
    .s_axi_rdata  (m_axi_rdata       ),
    .s_axi_rresp  (m_axi_rresp       ),
    .s_axi_rlast  (m_axi_rlast       ),
    .s_axi_rvalid (m_axi_rvalid      ),
    .s_axi_rready (m_axi_rready      )
  );


  // 3rd AXI interface, PCIe AXI4 bypass port
  // direct access to memory from host
  // --------------------------------------------
  bsg_axi4_pcie_mosi_s pcis_axi4_li;
  bsg_axi4_pcie_miso_s pcis_axi4_lo;

  bsg_axi4_mosi_bus_s axi4_pcie_lo;
  bsg_axi4_miso_bus_s axi4_pcie_li;

  assign pcis_axi4_li.awid     = m_axib_awid;
  assign pcis_axi4_li.awaddr   = m_axib_awaddr;
  assign pcis_axi4_li.awlen    = m_axib_awlen;
  assign pcis_axi4_li.awsize   = m_axib_awsize;
  assign pcis_axi4_li.awburst  = m_axib_awburst;
  assign pcis_axi4_li.awprot   = '0; // m_axib_awprot
  assign pcis_axi4_li.awregion = '0;
  assign pcis_axi4_li.awqos    = '0;
  assign pcis_axi4_li.awvalid  = m_axib_awvalid;
  assign pcis_axi4_li.awlock   = '0;  // m_axib_awlock
  assign pcis_axi4_li.awcache  = '0;  // m_axib_awcache
  assign pcis_axi4_li.wdata    = m_axib_wdata;
  assign pcis_axi4_li.wstrb    = m_axib_wstrb;
  assign pcis_axi4_li.wlast    = m_axib_wlast;
  assign pcis_axi4_li.wvalid   = m_axib_wvalid;
  assign pcis_axi4_li.bready   = m_axib_bready;
  assign pcis_axi4_li.arid     = m_axib_arid;
  assign pcis_axi4_li.araddr   = m_axib_araddr;
  assign pcis_axi4_li.arlen    = m_axib_arlen;
  assign pcis_axi4_li.arsize   = m_axib_arsize;
  assign pcis_axi4_li.arburst  = m_axib_arburst;
  assign pcis_axi4_li.arprot   = '0;  // m_axib_arprot
  assign pcis_axi4_li.arregion = '0;
  assign pcis_axi4_li.arqos    = '0;
  assign pcis_axi4_li.arvalid  = m_axib_arvalid;
  assign pcis_axi4_li.arlock   = '0;  // m_axib_arlock
  assign pcis_axi4_li.arcache  = '0;  // m_axib_arcache
  assign pcis_axi4_li.rready   = m_axib_rready;

  assign m_axib_awready = pcis_axi4_lo.awready;
  assign m_axib_wready  = pcis_axi4_lo.wready;
  assign m_axib_bid     = pcis_axi4_lo.bid;
  assign m_axib_bresp   = pcis_axi4_lo.bresp;
  assign m_axib_bvalid  = pcis_axi4_lo.bvalid;
  assign m_axib_arready = pcis_axi4_lo.arready;
  assign m_axib_rid     = pcis_axi4_lo.rid;
  assign m_axib_rdata   = pcis_axi4_lo.rdata;
  assign m_axib_rresp   = pcis_axi4_lo.rresp;
  assign m_axib_rlast   = pcis_axi4_lo.rlast;
  assign m_axib_rvalid  = pcis_axi4_lo.rvalid;

  // axi4_data_width_converter #(
  //   .id_width_p    (axi_id_width_p    ),
  //   .addr_width_p  (axi_addr_width_p  ),
  //   .s_data_width_p(axi_data_width_p  ),
  //   .m_data_width_p(axi_data_width_p/2),
  //   .device_family (DEVICE_FAMILY     )
  // ) pcie_dw_cvt (
  //   .clk_i   (clk_axi4_pcie_li    ),
  //   .reset_i (~rstn_axi4_pcie_li  ),
  //   .s_axi4_i(pcis_axi4_li ),
  //   .s_axi4_o(pcis_axi4_lo),
  //   .m_axi4_o(axi4_pcie_lo),
  //   .m_axi4_i(axi4_pcie_li)
  // );

  // assign axi4_pcie_lo.awid = '0;
  // assign axi4_pcie_lo.arid = '0;

  assign pcis_axi4_lo = '0;

 //--------------------------------------------
 // AXI-Lite OCL System
 //---------------------------------------------
  logic axil_rstn_buf;
  lib_pipe #(.WIDTH(1), .STAGES(4)) AXIL_RST_N (
    .clk    (clk_axi4_pcie_li ),
    .rst_n  (1'b1            ),
    .in_bus (rstn_axi4_pcie_li),
    .out_bus(axil_rstn_buf   )
  );

  bsg_axil_mosi_bus_s m_axil_ocl_lo;
  bsg_axil_miso_bus_s m_axil_ocl_li;

  axi_register_slice_light AXIL_OCL_REG_SLC (
    .aclk         (clk_axi4_pcie_li      ),
    .aresetn      (axil_rstn_buf        ),
    .s_axi_awaddr (s_axil_ocl_li.awaddr ),
    .s_axi_awprot (3'h0                 ),
    .s_axi_awvalid(s_axil_ocl_li.awvalid),
    .s_axi_awready(s_axil_ocl_lo.awready),
    .s_axi_wdata  (s_axil_ocl_li.wdata  ),
    .s_axi_wstrb  (s_axil_ocl_li.wstrb  ),
    .s_axi_wvalid (s_axil_ocl_li.wvalid ),
    .s_axi_wready (s_axil_ocl_lo.wready ),
    .s_axi_bresp  (s_axil_ocl_lo.bresp  ),
    .s_axi_bvalid (s_axil_ocl_lo.bvalid ),
    .s_axi_bready (s_axil_ocl_li.bready ),
    .s_axi_araddr (s_axil_ocl_li.araddr ),
    .s_axi_arvalid(s_axil_ocl_li.arvalid),
    .s_axi_arready(s_axil_ocl_lo.arready),
    .s_axi_rdata  (s_axil_ocl_lo.rdata  ),
    .s_axi_rresp  (s_axil_ocl_lo.rresp  ),
    .s_axi_rvalid (s_axil_ocl_lo.rvalid ),
    .s_axi_rready (s_axil_ocl_li.rready ),
    .m_axi_awaddr (m_axil_ocl_lo.awaddr  ),
    .m_axi_awprot (                     ),
    .m_axi_awvalid(m_axil_ocl_lo.awvalid ),
    .m_axi_awready(m_axil_ocl_li.awready ),
    .m_axi_wdata  (m_axil_ocl_lo.wdata   ),
    .m_axi_wstrb  (m_axil_ocl_lo.wstrb   ),
    .m_axi_wvalid (m_axil_ocl_lo.wvalid  ),
    .m_axi_wready (m_axil_ocl_li.wready  ),
    .m_axi_bresp  (m_axil_ocl_li.bresp   ),
    .m_axi_bvalid (m_axil_ocl_li.bvalid  ),
    .m_axi_bready (m_axil_ocl_lo.bready  ),
    .m_axi_araddr (m_axil_ocl_lo.araddr  ),
    .m_axi_arvalid(m_axil_ocl_lo.arvalid ),
    .m_axi_arready(m_axil_ocl_li.arready ),
    .m_axi_rdata  (m_axil_ocl_li.rdata   ),
    .m_axi_rresp  (m_axil_ocl_li.rresp   ),
    .m_axi_rvalid (m_axil_ocl_li.rvalid  ),
    .m_axi_rready (m_axil_ocl_lo.rready  )
  );

  bsg_axil_mosi_bus_s s_mc_axil_li, s_rst_axil_li;
  bsg_axil_miso_bus_s s_mc_axil_lo, s_rst_axil_lo;

  assign s_mc_axil_li = m_axil_ocl_lo;
  assign m_axil_ocl_li = s_mc_axil_lo;

  // // reserve the axil address space for soft reset
  // //
  // localparam num_axil_slot_lp = 2;
  // localparam soft_rst_base_addr_lp = 64'h10000;
  // localparam mc_mmio_base_addr_lp = 64'h00000;
  // localparam axil_base_addr_lp = {soft_rst_base_addr_lp, mc_mmio_base_addr_lp};

 //  axil_demux #(
 //    .num_axil_p            (num_axil_slot_lp                        ),
 //    .axil_base_addr_p      (128'h00000000_00010000_00000000_00000000),
 //    .axil_base_addr_width_p(16                                      ),
 //    .device_family         (DEVICE_FAMILY                          )
 //  ) axil_dm (
 //    .clk_i       (clk_axi4_pcie_li             ),
 //    .reset_i     (~rstn_axi4_pcie_li           ),
 //    .s_axil_ser_i(m_axil_ocl_lo                ),
 //    .s_axil_ser_o(m_axil_ocl_li                ),
 //    .m_axil_par_o({s_rst_axil_li, s_mc_axil_li}),
 //    .m_axil_par_i({s_rst_axil_lo, s_mc_axil_lo})
 //  );

 //  logic reset_soft_lo;
 //  axil_to_mem #(
 //    .mem_addr_width_p      (4                         ),
 //    .axil_base_addr_p      (32'(soft_rst_base_addr_lp)),
 //    .axil_base_addr_width_p(16                        )
 //  ) rst_probe (
 //    .clk_i       (clk_axi4_pcie_li  ),
 //    .reset_i     (~rstn_axi4_pcie_li),
 //    .s_axil_bus_i(s_rst_axil_li     ),
 //    .s_axil_bus_o(s_rst_axil_lo     ),
 //    .addr_o      (                  ),
 //    .wen_o       (                  ),
 //    .data_o      (                  ),
 //    .ren_o       (                  ),
 //    .data_i      (                  ),
 //    .done        (reset_soft_lo     )
 //  );

  wire reset_soft_lo = '0;
  // ---------------------------------------------
  // monitor LEDs
  // ---------------------------------------------

  // LEDs for pcie observation
  assign leds_o[0] = sys_rst_n_buf_lo;
//  assign leds_o[1] = rstn_axi4_pcie_li;
  qcl_breath_en #(.val_p('d1)) led_breath_rst (
    .clk_i  (clk_axi4_pcie_li                ),
    .reset_i(1'b0                            ),
    .en_i   (rstn_axi4_pcie_li| reset_soft_lo),
    .o      (leds_o[1]                       )
  );
  assign leds_o[2] = user_link_up_lo;
  assign leds_o[3] = user_clk_heartbeat[26];
  qcl_breath_en #(.val_p('d50000000)) led_breath_clk (
    .clk_i  (hbm_axil_clk_int),
    .reset_i(1'b0            ),
    .en_i   (1'b1            ),
    .o      (leds_o[4]       )
  );
  assign leds_o[5] = ~(&locked_pll);
  // axil traffic
  wire axil_wr_issued = m_axil_ocl_lo.wvalid & m_axil_ocl_li.wready;
  wire axil_rd_issued = m_axil_ocl_li.rvalid & m_axil_ocl_lo.rready;

  qcl_breath_en #(.val_p('d4)) led_breath_axil_wr (
    .clk_i  (clk_axi4_pcie_li),
    .reset_i(ext_reset_dbnc  ),
    .en_i   (axil_wr_issued  ),
    .o      (leds_o[6]       )
  );
  qcl_breath_en #(.val_p('d4)) led_breath_axil_rd (
    .clk_i  (clk_axi4_pcie_li),
    .reset_i(ext_reset_dbnc  ),
    .en_i   (axil_rd_issued  ),
    .o      (leds_o[7]       )
  );

  // ---------------------------------------------
  // bladerunner manycore
  // ---------------------------------------------

  localparam num_axi_slot_lp = (mem_cfg_p == e_vcache_blocking_axi4_hbm ||
                                mem_cfg_p == e_vcache_non_blocking_axi4_hbm) ?
                                num_tiles_x_p : 1;

  bsg_axi4_mosi_bus_s [num_axi_slot_lp-1:0] mc_axi4_cache_lo;
  bsg_axi4_miso_bus_s [num_axi_slot_lp-1:0] mc_axi4_cache_li;

  // hb_manycore
  bladerunner_wrapper #(
    .num_axi_mem_channels_p(num_axi_slot_lp ),
    .mc_to_io_cdc_p        (0               ),
    .mc_to_mem_cdc_p       (0               ),
    .axi_id_width_p        (axi_id_width_p  ),
    .axi_addr_width_p      (axi_addr_width_p),
    .axi_data_width_p      (axi_data_width_p)
  ) brunner (
    .clk_core_i  (clk_axi4_pcie_li                   ),
    .reset_core_i(mc_reset_i                         ),
    .clk_io_i    (clk_axi4_pcie_li                   ),
    .reset_io_i  (mc_reset_i                         ),
    .clk_mem_i   ({num_axi_slot_lp{clk_axi4_pcie_li}}),
    .reset_mem_i ({num_axi_slot_lp{mc_reset_i}}      ),
    // AXI-Lite
    .s_axil_bus_i(s_mc_axil_li                       ),
    .s_axil_bus_o(s_mc_axil_lo                       ),
    // AXI4 Master
    .m_axi4_bus_o(mc_axi4_cache_lo                   ),
    .m_axi4_bus_i(mc_axi4_cache_li                   )
  );

  bsg_axi4_mosi_bus_s [num_axi_slot_lp-1:0] s_axi4_cdc_li, m_axi4_cdc_lo;
  bsg_axi4_miso_bus_s [num_axi_slot_lp-1:0] s_axi4_cdc_lo, m_axi4_cdc_li;

  assign s_axi4_cdc_li = mc_axi4_cache_lo;
  assign mc_axi4_cache_li = s_axi4_cdc_lo;


  // hbm system reset
  wire APB_0_PRESET_N = ~ext_reset_dbnc;
  wire AXI_ARESET_N_0 = ~ext_reset_dbnc;

  ////////////////////////////////////////////////////////////////////////////////
  // Reg declaration
  ////////////////////////////////////////////////////////////////////////////////
  reg [3:0] cnt_rst_0       ;
  reg       axi_rst_0_r1_n  ;
  reg       axi_rst_0_mmcm_n;
  (* keep = "TRUE" *) reg           axi_rst_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst0_st0_r1_n, axi_rst0_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst0_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst1_st0_r1_n, axi_rst1_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst1_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst2_st0_r1_n, axi_rst2_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst2_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst3_st0_r1_n, axi_rst3_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst3_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst4_st0_r1_n, axi_rst4_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst4_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst5_st0_r1_n, axi_rst5_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst5_st0_n;
  (* ASYNC_REG = "TRUE" *) reg           axi_rst6_st0_r1_n, axi_rst6_st0_r2_n;
  (* dont_touch = "true" *) reg           axi_rst6_st0_n;


  ////////////////////////////////////////////////////////////////////////////////
  // Instantiating BUFG for AXI Clock
  ////////////////////////////////////////////////////////////////////////////////
  // (* keep = "TRUE" *) wire      APB_0_PCLK_IBUF;
  (* keep = "TRUE" *) wire      APB_0_PCLK_BUF;

  // IBUF u_APB_0_PCLK_IBUF  (
  //   .I (APB_0_PCLK),
  //   .O (APB_0_PCLK_IBUF)
  // );

  BUFG u_APB_0_PCLK_BUFG  (
    .I (APB_0_PCLK_IBUF),
    .O (APB_0_PCLK_BUF)
  );

    wire AXI_ACLK_IN_0;
  // BUFG u_AXI_ACLK_IN_0  (
  //   .I (AXI_ACLK_IN_0),
  //   .O (AXI_ACLK_IN_0_buf)
  // );

  ////////////////////////////////////////////////////////////////////////////////
  // Reset logic for AXI_0
  ////////////////////////////////////////////////////////////////////////////////
  always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst_0_r1_n <= 1'b0;
    end else begin
      axi_rst_0_r1_n <= 1'b1;
    end
  end

  always @ (posedge AXI_ACLK_IN_0_buf) begin
    if (~axi_rst_0_r1_n) begin
      cnt_rst_0 <= 4'hA;
    end else if (cnt_rst_0 != 4'h0) begin
      cnt_rst_0 <= cnt_rst_0 - 1'b1;
    end else begin
      cnt_rst_0 <= cnt_rst_0;
    end
  end

  always @ (posedge AXI_ACLK_IN_0_buf) begin
    if (cnt_rst_0 != 4'h0) begin
      axi_rst_0_mmcm_n <= 1'b0;
    end else begin
      axi_rst_0_mmcm_n <= 1'b1;
    end
  end

  always @ (posedge AXI_ACLK_IN_0_buf) begin
    axi_rst_st0_n <= axi_rst_0_mmcm_n & MMCM_LOCK_0;
  end

  always @ (posedge AXI_ACLK0_st0_buf) begin
    axi_rst0_st0_r1_n <= axi_rst_st0_n;
    axi_rst0_st0_r2_n <= axi_rst0_st0_r1_n;
  end

  always @ (posedge AXI_ACLK0_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst0_st0_n <= 1'b0;
    end else begin
      axi_rst0_st0_n <= axi_rst0_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK1_st0_buf) begin
    axi_rst1_st0_r1_n <= axi_rst_st0_n;
    axi_rst1_st0_r2_n <= axi_rst1_st0_r1_n;
  end

  always @ (posedge AXI_ACLK1_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst1_st0_n <= 1'b0;
    end else begin
      axi_rst1_st0_n <= axi_rst1_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK2_st0_buf) begin
    axi_rst2_st0_r1_n <= axi_rst_st0_n;
    axi_rst2_st0_r2_n <= axi_rst2_st0_r1_n;
  end

  always @ (posedge AXI_ACLK2_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst2_st0_n <= 1'b0;
    end else begin
      axi_rst2_st0_n <= axi_rst2_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK3_st0_buf) begin
    axi_rst3_st0_r1_n <= axi_rst_st0_n;
    axi_rst3_st0_r2_n <= axi_rst3_st0_r1_n;
  end

  always @ (posedge AXI_ACLK3_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst3_st0_n <= 1'b0;
    end else begin
      axi_rst3_st0_n <= axi_rst3_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK4_st0_buf) begin
    axi_rst4_st0_r1_n <= axi_rst_st0_n;
    axi_rst4_st0_r2_n <= axi_rst4_st0_r1_n;
  end

  always @ (posedge AXI_ACLK4_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst4_st0_n <= 1'b0;
    end else begin
      axi_rst4_st0_n <= axi_rst4_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK5_st0_buf) begin
    axi_rst5_st0_r1_n <= axi_rst_st0_n;
    axi_rst5_st0_r2_n <= axi_rst5_st0_r1_n;
  end

  always @ (posedge AXI_ACLK5_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst5_st0_n <= 1'b0;
    end else begin
      axi_rst5_st0_n <= axi_rst5_st0_r2_n;
    end
  end

  always @ (posedge AXI_ACLK6_st0_buf) begin
    axi_rst6_st0_r1_n <= axi_rst_st0_n;
    axi_rst6_st0_r2_n <= axi_rst6_st0_r1_n;
  end

  always @ (posedge AXI_ACLK6_st0_buf or negedge AXI_ARESET_N_0) begin
    if (~AXI_ARESET_N_0) begin
      axi_rst6_st0_n <= 1'b0;
    end else begin
      axi_rst6_st0_n <= axi_rst6_st0_r2_n;
    end
  end

  reg  [7:0]    cnt_rst_0_0;
  // reg           axi_rst_0_mmcm_n_0;

  always @ (posedge AXI_ACLK_IN_0_buf) begin
    if (~axi_rst_0_r1_n) begin
      if( cnt_rst_0_0 >= 8'd100 )
      begin
        cnt_rst_0_0 <= cnt_rst_0_0;
        axi_rst_0_mmcm_n_0 <= 1'b0;
      end
      else
      begin
        cnt_rst_0_0 <= cnt_rst_0_0 + 1;
        axi_rst_0_mmcm_n_0 <= axi_rst_0_mmcm_n_0;
      end
    end else begin
      cnt_rst_0_0 <= 'd0;
      axi_rst_0_mmcm_n_0 <= 1'b1;
    end
  end


  logic [num_max_hbm_chs_lp-1:0] aclk_mem_ch_buf;
  logic [num_max_hbm_chs_lp-1:0] rstn_mem_ch_buf;

  assign aclk_mem_ch_buf[0] = AXI_ACLK0_st0_buf;
  assign rstn_mem_ch_buf[0] = axi_rst0_st0_n;
  assign aclk_mem_ch_buf[1] = AXI_ACLK0_st0_buf;
  assign rstn_mem_ch_buf[1] = axi_rst0_st0_n;

  assign aclk_mem_ch_buf[2] = AXI_ACLK1_st0_buf;
  assign rstn_mem_ch_buf[2] = axi_rst1_st0_n;
  assign aclk_mem_ch_buf[3] = AXI_ACLK1_st0_buf;
  assign rstn_mem_ch_buf[3] = axi_rst1_st0_n;

  assign aclk_mem_ch_buf[4] = AXI_ACLK2_st0_buf;
  assign rstn_mem_ch_buf[4] = axi_rst2_st0_n;
  assign aclk_mem_ch_buf[5] = AXI_ACLK2_st0_buf;
  assign rstn_mem_ch_buf[5] = axi_rst2_st0_n;

  assign aclk_mem_ch_buf[6] = AXI_ACLK3_st0_buf;
  assign rstn_mem_ch_buf[6] = axi_rst3_st0_n;
  assign aclk_mem_ch_buf[7] = AXI_ACLK3_st0_buf;
  assign rstn_mem_ch_buf[7] = axi_rst3_st0_n;

  assign aclk_mem_ch_buf[8] = AXI_ACLK4_st0_buf;
  assign rstn_mem_ch_buf[8] = axi_rst4_st0_n;
  assign aclk_mem_ch_buf[9] = AXI_ACLK4_st0_buf;
  assign rstn_mem_ch_buf[9] = axi_rst4_st0_n;

  assign aclk_mem_ch_buf[10] = AXI_ACLK5_st0_buf;
  assign rstn_mem_ch_buf[10] = axi_rst5_st0_n;
  assign aclk_mem_ch_buf[11] = AXI_ACLK5_st0_buf;
  assign rstn_mem_ch_buf[11] = axi_rst5_st0_n;
  assign aclk_mem_ch_buf[12] = AXI_ACLK5_st0_buf;
  assign rstn_mem_ch_buf[12] = axi_rst5_st0_n;

  assign aclk_mem_ch_buf[13] = AXI_ACLK6_st0_buf;
  assign rstn_mem_ch_buf[13] = axi_rst6_st0_n;
  assign aclk_mem_ch_buf[14] = AXI_ACLK6_st0_buf;
  assign rstn_mem_ch_buf[14] = axi_rst6_st0_n;
  assign aclk_mem_ch_buf[15] = AXI_ACLK6_st0_buf;
  assign rstn_mem_ch_buf[15] = axi_rst6_st0_n;


  // ---------------------------------------------
  // axi4 memory clock domain crossing
  // ---------------------------------------------

  // logic axi4_clk_cvt_rstn_buf;
  // lib_pipe #(.WIDTH(1), .STAGES(4)) AXI4_CDC_RST_N (
  //   .clk    (clk_axi4_pcie_li     ),
  //   .rst_n  (1'b1                 ),
  //   .in_bus (rstn_axi4_pcie_li    ),
  //   .out_bus(axi4_clk_cvt_rstn_buf)
  // );

  for (genvar i = 0; i < num_axi_slot_lp; i++) begin : mem_cdc

    axi4_clock_converter #(
      .device_family     (DEVICE_FAMILY   ),
      .axi4_id_width_p   (axi_id_width_p  ),
      .axi4_addr_width_p (axi_addr_width_p),
      .axi4_data_width_p (axi_data_width_p),
      .s_axi_aclk_ratio_p(1               ),
      .m_axi_aclk_ratio_p(2               ),
      .is_aclk_async_p   (1               )
    ) axi4_clk_cvt (
      .clk_src_i   (clk_axi4_pcie_li   ),
      .reset_src_i (~rstn_axi4_pcie_li ),
      .clk_dst_i   (aclk_mem_ch_buf[i] ),
      .reset_dst_i (~rstn_mem_ch_buf[i]),
      .s_axi4_src_i(s_axi4_cdc_li[i]   ),
      .s_axi4_src_o(s_axi4_cdc_lo[i]   ),
      .m_axi4_dst_o(m_axi4_cdc_lo[i]   ),
      .m_axi4_dst_i(m_axi4_cdc_li[i]   )
    );

  end : mem_cdc


  // ---------------------------------------------
  // axi4 memory level 3
  // ---------------------------------------------

  if (mem_cfg_p == e_vcache_blocking_axi4_bram) begin : lv3_axi4_bram

    assign s_axi4_bram_li   = m_axi4_cdc_lo[0];
    assign m_axi4_cdc_li[0] = s_axi4_bram_lo;

    blk_mem_gen_0 bram_mem (
      .rsta_busy    (                                               ), // output wire rsta_busy
      .rstb_busy    (                                               ), // output wire rstb_busy
      .s_aclk       (aclk_mem_ch_buf[0]                             ), // input wire s_axi_aclk
      .s_aresetn    (rstn_mem_ch_buf[0]                             ), // input wire s_axi_aresetn
      .s_axi_awid   (s_axi4_bram_li.awid                            ), // input wire [5 : 0] s_axi_awid
      .s_axi_awaddr (s_axi4_bram_li.awaddr[0][bram_addr_width_p-1:0]), // input wire [17 : 0] s_axi_awaddr
      .s_axi_awlen  (s_axi4_bram_li.awlen                           ), // input wire [7 : 0] s_axi_awlen
      .s_axi_awsize (s_axi4_bram_li.awsize                          ), // input wire [2 : 0] s_axi_awsize
      .s_axi_awburst(s_axi4_bram_li.awburst                         ), // input wire [1 : 0] s_axi_awburst
      // .s_axi_awlock (s_axi4_bram_li.awlock                          ), // input wire s_axi_awlock
      // .s_axi_awcache(s_axi4_bram_li.awcache                         ), // input wire [3 : 0] s_axi_awcache
      // .s_axi_awprot (s_axi4_bram_li.awprot                          ), // input wire [2 : 0] s_axi_awprot
      .s_axi_awvalid(s_axi4_bram_li.awvalid                         ), // input wire s_axi_awvalid
      .s_axi_awready(s_axi4_bram_lo.awready                         ), // output wire s_axi_awready
      .s_axi_wdata  (s_axi4_bram_li.wdata                           ), // input wire [mem_dwidth-1 : 0] s_axi_wdata
      .s_axi_wstrb  (s_axi4_bram_li.wstrb                           ), // input wire [31 : 0] s_axi_wstrb
      .s_axi_wlast  (s_axi4_bram_li.wlast                           ), // input wire s_axi_wlast
      .s_axi_wvalid (s_axi4_bram_li.wvalid                          ), // input wire s_axi_wvalid
      .s_axi_wready (s_axi4_bram_lo.wready                          ), // output wire s_axi_wready
      .s_axi_bid    (s_axi4_bram_lo.bid                             ), // output wire [5 : 0] s_axi_bid
      .s_axi_bresp  (s_axi4_bram_lo.bresp                           ), // output wire [1 : 0] s_axi_bresp
      .s_axi_bvalid (s_axi4_bram_lo.bvalid                          ), // output wire s_axi_bvalid
      .s_axi_bready (s_axi4_bram_li.bready                          ), // input wire s_axi_bready
      .s_axi_arid   (s_axi4_bram_li.arid                            ), // input wire [5 : 0] s_axi_arid
      .s_axi_araddr (s_axi4_bram_li.araddr[0][bram_addr_width_p-1:0]), // input wire [17 : 0] s_axi_araddr
      .s_axi_arlen  (s_axi4_bram_li.arlen                           ), // input wire [7 : 0] s_axi_arlen
      .s_axi_arsize (s_axi4_bram_li.arsize                          ), // input wire [2 : 0] s_axi_arsize
      .s_axi_arburst(s_axi4_bram_li.arburst                         ), // input wire [1 : 0] s_axi_arburst
      // .s_axi_arlock (s_axi4_bram_li.arlock                          ), // input wire s_axi_arlock
      // .s_axi_arcache(s_axi4_bram_li.arcache                         ), // input wire [3 : 0] s_axi_arcache
      // .s_axi_arprot (s_axi4_bram_li.arprot                          ), // input wire [2 : 0] s_axi_arprot
      .s_axi_arvalid(s_axi4_bram_li.arvalid                         ), // input wire s_axi_arvalid
      .s_axi_arready(s_axi4_bram_lo.arready                         ), // output wire s_axi_arready
      .s_axi_rid    (s_axi4_bram_lo.rid                             ), // output wire [5 : 0] s_axi_rid
      .s_axi_rdata  (s_axi4_bram_lo.rdata                           ), // output wire [mem_dwidth-1 : 0] s_axi_rdata
      .s_axi_rresp  (s_axi4_bram_lo.rresp                           ), // output wire [1 : 0] s_axi_rresp
      .s_axi_rlast  (s_axi4_bram_lo.rlast                           ), // output wire s_axi_rlast
      .s_axi_rvalid (s_axi4_bram_lo.rvalid                          ), // output wire s_axi_rvalid
      .s_axi_rready (s_axi4_bram_li.rready                          )  // input wire s_axi_rready
    );

  end : lv3_axi4_bram

  // else if (mem_cfg_p == e_vcache_blocking_axi4_xbar_dram ||
  //          mem_cfg_p == e_vcache_blocking_axi4_xbar_model) begin : lv3_axi4_xbar
  //   //synopsys translate_off
  //   initial begin
  //     $fatal(0, "xbar_dram Not supported!\n");
  //   end
  //   // synopsys translate_on
  // end : lv3_axi4_xbar

  // ===================================
  // hbm memory system
  // ===================================
  else if (mem_cfg_p == e_vcache_blocking_axi4_hbm ||
    mem_cfg_p == e_vcache_non_blocking_axi4_hbm) begin : lv3_hbm

    for (genvar i = 0; i < num_axi_slot_lp; i++) begin : axi_dv_cvt
      always_comb begin : hbm_addr_map
        axi4_hbm_chs_li[i] = m_axi4_cdc_lo[i];
        axi4_hbm_chs_li[i].awaddr[0][32:0] = m_axi4_cdc_lo[i].awaddr[0][31:0] | 33'(i<<28); // we are using 4H stack, tell from example
        axi4_hbm_chs_li[i].araddr[0][32:0] = m_axi4_cdc_lo[i].araddr[0][31:0] | 33'(i<<28);
        m_axi4_cdc_li[i] = axi4_hbm_chs_lo[i];
      end : hbm_addr_map
    end : axi_dv_cvt


    `ifndef SIMULATION_MODE
      wire [31:0]  APB_0_PWDATA  = 32'b0;
      wire [21:0]  APB_0_PADDR   = 22'b0;
      wire         APB_0_PENABLE = 1'b0 ;
      wire         APB_0_PSEL    = 1'b0 ;
      wire         APB_0_PWRITE  = 1'b0 ;
      wire [31:0]  APB_0_PRDATA         ;
      wire         APB_0_PREADY         ;
      wire         APB_0_PSLVERR        ;
    `endif

    logic [num_max_hbm_chs_lp-1:0][APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_0  ;
    logic [num_max_hbm_chs_lp-1:0][APP_ADDR_WIDTH-1:0] o_m_axi_araddr_0  ;
    logic [num_max_hbm_chs_lp-1:0][              32:0] AXI_ARADDR        ;
    logic [num_max_hbm_chs_lp-1:0][               1:0] AXI_ARBURST       ;
    logic [num_max_hbm_chs_lp-1:0][               5:0] AXI_ARID          ;
    logic [num_max_hbm_chs_lp-1:0][               7:0] AXI_ARLEN         ;
    logic [num_max_hbm_chs_lp-1:0][               2:0] AXI_ARSIZE        ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_ARVALID       ;
    logic [num_max_hbm_chs_lp-1:0][              32:0] AXI_AWADDR        ;
    logic [num_max_hbm_chs_lp-1:0][               1:0] AXI_AWBURST       ;
    logic [num_max_hbm_chs_lp-1:0][               5:0] AXI_AWID          ;
    logic [num_max_hbm_chs_lp-1:0][               7:0] AXI_AWLEN         ;
    logic [num_max_hbm_chs_lp-1:0][               2:0] AXI_AWSIZE        ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_AWVALID       ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_RREADY        ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_BREADY        ;
    logic [num_max_hbm_chs_lp-1:0][             255:0] AXI_WDATA         ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_WLAST         ;
    logic [num_max_hbm_chs_lp-1:0][              31:0] AXI_WSTRB         ;
    logic [num_max_hbm_chs_lp-1:0][              31:0] AXI_WDATA_PARITY_i;
    logic [num_max_hbm_chs_lp-1:0][              31:0] AXI_WDATA_PARITY  ;
    logic [num_max_hbm_chs_lp-1:0]                     AXI_WVALID        ;
    logic [num_max_hbm_chs_lp-1:0][               3:0] AXI_ARCACHE       ;
    logic [num_max_hbm_chs_lp-1:0][               3:0] AXI_AWCACHE       ;
    logic [num_max_hbm_chs_lp-1:0][               2:0] AXI_AWPROT        ;
    `ifndef SIMULATION_MODE
      logic [num_max_hbm_chs_lp-1:0] boot_mode_done_0;
    `endif
    logic [num_max_hbm_chs_lp-1:0][31:0]      prbs_mode_seed_0 = 32'habcd_1234;

    logic [num_max_hbm_chs_lp-1:0]        AXI_ARREADY     ;
    logic [num_max_hbm_chs_lp-1:0]        AXI_AWREADY     ;
    logic [num_max_hbm_chs_lp-1:0][ 31:0] AXI_RDATA_PARITY;
    logic [num_max_hbm_chs_lp-1:0][255:0] AXI_RDATA       ;
    logic [num_max_hbm_chs_lp-1:0][  5:0] AXI_RID         ;
    logic [num_max_hbm_chs_lp-1:0]        AXI_RLAST       ;
    logic [num_max_hbm_chs_lp-1:0][  1:0] AXI_RRESP       ;
    logic [num_max_hbm_chs_lp-1:0]        AXI_RVALID      ;
    logic [num_max_hbm_chs_lp-1:0]        AXI_WREADY      ;
    logic [num_max_hbm_chs_lp-1:0][  5:0] AXI_BID         ;
    logic [num_max_hbm_chs_lp-1:0][  1:0] AXI_BRESP       ;
    logic [num_max_hbm_chs_lp-1:0]        AXI_BVALID      ;



    ////////////////////////////////////////////////////////////////////////////////
    // Instantiating AXI_TG - 0
    ////////////////////////////////////////////////////////////////////////////////
    // assign AXI_ARADDR = {vio_tg_glb_start_addr_0[32:28],o_m_axi_araddr_0[27:0]};
    // assign AXI_AWADDR = {vio_tg_glb_start_addr_0[32:28],o_m_axi_awaddr_0[27:0]};
    for (genvar i = 0; i < num_max_hbm_chs_lp; i++) begin : data_assign
      //  mosi signals
      assign AXI_AWID[i] = axi4_hbm_chs_li[i].awid;
      assign AXI_AWADDR[i]  = axi4_hbm_chs_li[i].awaddr[0][32:0];
      assign AXI_AWLEN[i]   = axi4_hbm_chs_li[i].awlen;
      assign AXI_AWSIZE[i]  = axi4_hbm_chs_li[i].awsize;
      assign AXI_AWBURST[i] = axi4_hbm_chs_li[i].awburst;
      // assign AXI_awlock[i] = axi4_hbm_chs_li[i].awlock;
      assign AXI_AWCACHE[i] = axi4_hbm_chs_li[i].awcache;
      assign AXI_AWPROT[i]  = axi4_hbm_chs_li[i].awprot;
      assign AXI_AWVALID[i] = axi4_hbm_chs_li[i].awvalid;
      assign AXI_WDATA[i]   = axi4_hbm_chs_li[i].wdata;
      assign AXI_WSTRB[i]   = axi4_hbm_chs_li[i].wstrb;
      assign AXI_WLAST[i]   = axi4_hbm_chs_li[i].wlast;
      assign AXI_WVALID[i]  = axi4_hbm_chs_li[i].wvalid;
      assign AXI_BREADY[i]  = axi4_hbm_chs_li[i].bready;
      assign AXI_ARID[i]    = axi4_hbm_chs_li[i].arid;
      assign AXI_ARADDR[i]  = axi4_hbm_chs_li[i].araddr[0][32:0];
      assign AXI_ARLEN[i]   = axi4_hbm_chs_li[i].arlen;
      assign AXI_ARSIZE[i]  = axi4_hbm_chs_li[i].arsize;
      assign AXI_ARBURST[i] = axi4_hbm_chs_li[i].arburst;
      // assign ([i] = axi4_hbm_chs_li[i].arburst;
      assign AXI_ARCACHE[i] = axi4_hbm_chs_li[i].arcache;
      // assign ([i] = axi4_hbm_chs_li[i].arprot;
      assign AXI_ARVALID[i] = axi4_hbm_chs_li[i].arvalid;
      assign AXI_RREADY[i]  = axi4_hbm_chs_li[i].rready;

      //  miso signals
      assign axi4_hbm_chs_lo[i].awready = AXI_AWREADY[i];
      assign axi4_hbm_chs_lo[i].wready  = AXI_WREADY[i];
      assign axi4_hbm_chs_lo[i].bid     = AXI_BID[i];
      assign axi4_hbm_chs_lo[i].bresp   = AXI_BRESP[i];
      assign axi4_hbm_chs_lo[i].bvalid  = AXI_BVALID[i];
      assign axi4_hbm_chs_lo[i].arready = AXI_ARREADY[i];
      assign axi4_hbm_chs_lo[i].rid     = AXI_RID[i];
      assign axi4_hbm_chs_lo[i].rresp   = AXI_RRESP[i];
      assign axi4_hbm_chs_lo[i].rvalid  = AXI_RVALID[i];
      assign axi4_hbm_chs_lo[i].rdata   = AXI_RDATA[i];
      assign axi4_hbm_chs_lo[i].rlast   = AXI_RLAST[i];
    end

    // synthesis translate off
    for (genvar i = 0; i < num_max_hbm_chs_lp; i++) begin : mon
      ////////////////////////////////////////////////////////////////////////////////
      // Instantiating AXI_PMON - 0
      ////////////////////////////////////////////////////////////////////////////////
      axi_pmon_v1_0 #(
        .C_AXI_ID_WIDTH  (6     ),
        .C_AXI_ADDR_WIDTH(33    ),
        .C_AXI_DATA_WIDTH(256   ),
        .SIMULATION      ("TRUE"),
        .tCK             (2222  ),
        .PARAM_AXI_TG_ID (0     )
      ) u_axi_pmon_0 (
        .axi_arst_n (axi_rst0_st0_n   ),
        .axi_aclk   (AXI_ACLK0_st0_buf),
        .axi_awid   (AXI_AWID[i]      ),
        .axi_awaddr (AXI_AWADDR[i]    ),
        .axi_awlen  (AXI_AWLEN[i]     ),
        .axi_awsize (AXI_AWSIZE[i]    ),
        .axi_awburst(AXI_AWBURST[i]   ),
        .axi_awcache(AXI_AWCACHE[i]   ),
        .axi_awprot (AXI_AWPROT[i]    ),
        .axi_awvalid(AXI_AWVALID[i]   ),
        .axi_awready(AXI_AWREADY[i]   ),
        .axi_wdata  (AXI_WDATA[i]     ),
        .axi_wstrb  (AXI_WSTRB[i]     ),
        .axi_wlast  (AXI_WLAST[i]     ),
        .axi_wvalid (AXI_WVALID[i]    ),
        .axi_wready (AXI_WREADY[i]    ),
        .axi_bready (AXI_BREADY[i]    ),
        .axi_bid    (AXI_BID[i]       ),
        .axi_bresp  (AXI_BRESP[i]     ),
        .axi_bvalid (AXI_BVALID[i]    ),
        .axi_arid   (AXI_ARID[i]      ),
        .axi_araddr (AXI_ARADDR[i]    ),
        .axi_arlen  (AXI_ARLEN[i]     ),
        .axi_arsize (AXI_ARSIZE[i]    ),
        .axi_arburst(AXI_ARBURST[i]   ),
        .axi_arcache(AXI_ARCACHE[i]   ),
        .axi_arvalid(AXI_ARVALID[i]   ),
        .axi_arready(AXI_ARREADY[i]   ),
        .axi_rready (AXI_RREADY[i]    ),
        .axi_rid    (AXI_RID[i]       ),
        .axi_rdata  (AXI_RDATA[i]     ),
        .axi_rresp  (AXI_RRESP[i]     ),
        .axi_rlast  (AXI_RLAST[i]     ),
        .axi_rvalid (AXI_RVALID[i]    )
      );
    end
    // synthesis translate on


    ////////////////////////////////////////////////////////////////////////////////
    // Calculating Write Data Parity
    ////////////////////////////////////////////////////////////////////////////////
    for (genvar i = 0; i < num_max_hbm_chs_lp; i++) begin
      assign AXI_WDATA_PARITY_i[i] = {{^(AXI_WDATA[i][255:248])},{^(AXI_WDATA[i][247:240])},{^(AXI_WDATA[i][239:232])},{^(AXI_WDATA[i][231:224])},
        {^(AXI_WDATA[i][223:216])},{^(AXI_WDATA[i][215:208])},{^(AXI_WDATA[i][207:200])},{^(AXI_WDATA[i][199:192])},
        {^(AXI_WDATA[i][191:184])},{^(AXI_WDATA[i][183:176])},{^(AXI_WDATA[i][175:168])},{^(AXI_WDATA[i][167:160])},
        {^(AXI_WDATA[i][159:152])},{^(AXI_WDATA[i][151:144])},{^(AXI_WDATA[i][143:136])},{^(AXI_WDATA[i][135:128])},
        {^(AXI_WDATA[i][127:120])},{^(AXI_WDATA[i][119:112])},{^(AXI_WDATA[i][111:104])},{^(AXI_WDATA[i][103:96])},
        {^(AXI_WDATA[i][95:88])},  {^(AXI_WDATA[i][87:80])},  {^(AXI_WDATA[i][79:72])},  {^(AXI_WDATA[i][71:64])},
        {^(AXI_WDATA[i][63:56])},  {^(AXI_WDATA[i][55:48])},  {^(AXI_WDATA[i][47:40])},  {^(AXI_WDATA[i][39:32])},
        {^(AXI_WDATA[i][31:24])},  {^(AXI_WDATA[i][23:16])},  {^(AXI_WDATA[i][15:8])},   {^(AXI_WDATA[i][7:0])}};
    end

    always @(posedge aclk_mem_ch_buf[0])
      AXI_WDATA_PARITY[0] <= AXI_WDATA_PARITY_i[0];

    always @(posedge aclk_mem_ch_buf[0])
      AXI_WDATA_PARITY[1] <= AXI_WDATA_PARITY_i[1];


    always @(posedge aclk_mem_ch_buf[1])
      AXI_WDATA_PARITY[2] <= AXI_WDATA_PARITY_i[2];

    always @(posedge aclk_mem_ch_buf[1])
      AXI_WDATA_PARITY[3] <= AXI_WDATA_PARITY_i[3];


    always @(posedge aclk_mem_ch_buf[2])
      AXI_WDATA_PARITY[4] <= AXI_WDATA_PARITY_i[4];

    always @(posedge aclk_mem_ch_buf[2])
      AXI_WDATA_PARITY[5] <= AXI_WDATA_PARITY_i[5];


    always @(posedge aclk_mem_ch_buf[3])
      AXI_WDATA_PARITY[6] <= AXI_WDATA_PARITY_i[6];

    always @(posedge aclk_mem_ch_buf[3])
      AXI_WDATA_PARITY[7] <= AXI_WDATA_PARITY_i[7];


    always @(posedge aclk_mem_ch_buf[4])
      AXI_WDATA_PARITY[8] <= AXI_WDATA_PARITY_i[8];

    always @(posedge aclk_mem_ch_buf[4])
      AXI_WDATA_PARITY[9] <= AXI_WDATA_PARITY_i[9];


    always @(posedge aclk_mem_ch_buf[5])
      AXI_WDATA_PARITY[10] <= AXI_WDATA_PARITY_i[10];

    always @(posedge aclk_mem_ch_buf[5])
      AXI_WDATA_PARITY[11] <= AXI_WDATA_PARITY_i[11];

    always @(posedge aclk_mem_ch_buf[5])
      AXI_WDATA_PARITY[12] <= AXI_WDATA_PARITY_i[12];


    always @(posedge aclk_mem_ch_buf[6])
      AXI_WDATA_PARITY[13] <= AXI_WDATA_PARITY_i[13];

    always @(posedge aclk_mem_ch_buf[6])
      AXI_WDATA_PARITY[14] <= AXI_WDATA_PARITY_i[14];

    always @(posedge aclk_mem_ch_buf[6])
      AXI_WDATA_PARITY[15] <= AXI_WDATA_PARITY_i[15];


    wire         DRAM_0_STAT_CATTRIP;
    wire [6:0]   DRAM_0_STAT_TEMP   ;

    wire apb_seq_complete_0_s;

////////////////////////////////////////////////////////////////////////////////
// Instantiating User Design
////////////////////////////////////////////////////////////////////////////////
    hbm_0 u_hbm_0 (
      .HBM_REF_CLK_0      (HBM_REF_CLK_0         ),

      .AXI_00_ACLK        (AXI_ACLK0_st0_buf     ),
      .AXI_00_ARESET_N    (axi_rst0_st0_n        ),
      .AXI_00_ARADDR      (AXI_ARADDR[0]         ),
      .AXI_00_ARBURST     (AXI_ARBURST[0]        ),
      .AXI_00_ARID        (AXI_ARID[0]           ),
      .AXI_00_ARLEN       (AXI_ARLEN[0][3:0]     ),
      .AXI_00_ARSIZE      (AXI_ARSIZE[0]         ),
      .AXI_00_ARVALID     (AXI_ARVALID[0]        ),
      .AXI_00_AWADDR      (AXI_AWADDR[0]         ),
      .AXI_00_AWBURST     (AXI_AWBURST[0]        ),
      .AXI_00_AWID        (AXI_AWID[0]           ),
      .AXI_00_AWLEN       (AXI_AWLEN[0][3:0]     ),
      .AXI_00_AWSIZE      (AXI_AWSIZE[0]         ),
      .AXI_00_AWVALID     (AXI_AWVALID[0]        ),
      .AXI_00_RREADY      (AXI_RREADY[0]         ),
      .AXI_00_BREADY      (AXI_BREADY[0]         ),
      .AXI_00_WDATA       (AXI_WDATA[0]          ),
      .AXI_00_WLAST       (AXI_WLAST[0]          ),
      .AXI_00_WSTRB       (AXI_WSTRB[0]          ),
      .AXI_00_WDATA_PARITY(AXI_WDATA_PARITY_i[0] ),
      .AXI_00_WVALID      (AXI_WVALID[0]         ),

      .AXI_01_ACLK        (AXI_ACLK0_st0_buf     ),
      .AXI_01_ARESET_N    (axi_rst0_st0_n        ),
      .AXI_01_ARADDR      (AXI_ARADDR[1]         ),
      .AXI_01_ARBURST     (AXI_ARBURST[1]        ),
      .AXI_01_ARID        (AXI_ARID[1]           ),
      .AXI_01_ARLEN       (AXI_ARLEN[1][3:0]     ),
      .AXI_01_ARSIZE      (AXI_ARSIZE[1]         ),
      .AXI_01_ARVALID     (AXI_ARVALID[1]        ),
      .AXI_01_AWADDR      (AXI_AWADDR[1]         ),
      .AXI_01_AWBURST     (AXI_AWBURST[1]        ),
      .AXI_01_AWID        (AXI_AWID[1]           ),
      .AXI_01_AWLEN       (AXI_AWLEN[1][3:0]     ),
      .AXI_01_AWSIZE      (AXI_AWSIZE[1]         ),
      .AXI_01_AWVALID     (AXI_AWVALID[1]        ),
      .AXI_01_RREADY      (AXI_RREADY[1]         ),
      .AXI_01_BREADY      (AXI_BREADY[1]         ),
      .AXI_01_WDATA       (AXI_WDATA[1]          ),
      .AXI_01_WLAST       (AXI_WLAST[1]          ),
      .AXI_01_WSTRB       (AXI_WSTRB[1]          ),
      .AXI_01_WDATA_PARITY(AXI_WDATA_PARITY_i[1] ),
      .AXI_01_WVALID      (AXI_WVALID[1]         ),

      .AXI_02_ACLK        (AXI_ACLK1_st0_buf     ),
      .AXI_02_ARESET_N    (axi_rst1_st0_n        ),
      .AXI_02_ARADDR      (AXI_ARADDR[2]         ),
      .AXI_02_ARBURST     (AXI_ARBURST[2]        ),
      .AXI_02_ARID        (AXI_ARID[2]           ),
      .AXI_02_ARLEN       (AXI_ARLEN[2][3:0]     ),
      .AXI_02_ARSIZE      (AXI_ARSIZE[2]         ),
      .AXI_02_ARVALID     (AXI_ARVALID[2]        ),
      .AXI_02_AWADDR      (AXI_AWADDR[2]         ),
      .AXI_02_AWBURST     (AXI_AWBURST[2]        ),
      .AXI_02_AWID        (AXI_AWID[2]           ),
      .AXI_02_AWLEN       (AXI_AWLEN[2][3:0]     ),
      .AXI_02_AWSIZE      (AXI_AWSIZE[2]         ),
      .AXI_02_AWVALID     (AXI_AWVALID[2]        ),
      .AXI_02_RREADY      (AXI_RREADY[2]         ),
      .AXI_02_BREADY      (AXI_BREADY[2]         ),
      .AXI_02_WDATA       (AXI_WDATA[2]          ),
      .AXI_02_WLAST       (AXI_WLAST[2]          ),
      .AXI_02_WSTRB       (AXI_WSTRB[2]          ),
      .AXI_02_WDATA_PARITY(AXI_WDATA_PARITY_i[2] ),
      .AXI_02_WVALID      (AXI_WVALID[2]         ),
      .AXI_03_ACLK        (AXI_ACLK1_st0_buf     ),
      .AXI_03_ARESET_N    (axi_rst1_st0_n        ),
      .AXI_03_ARADDR      (AXI_ARADDR[3]         ),
      .AXI_03_ARBURST     (AXI_ARBURST[3]        ),
      .AXI_03_ARID        (AXI_ARID[3]           ),
      .AXI_03_ARLEN       (AXI_ARLEN[3][3:0]     ),
      .AXI_03_ARSIZE      (AXI_ARSIZE[3]         ),
      .AXI_03_ARVALID     (AXI_ARVALID[3]        ),
      .AXI_03_AWADDR      (AXI_AWADDR[3]         ),
      .AXI_03_AWBURST     (AXI_AWBURST[3]        ),
      .AXI_03_AWID        (AXI_AWID[3]           ),
      .AXI_03_AWLEN       (AXI_AWLEN[3][3:0]     ),
      .AXI_03_AWSIZE      (AXI_AWSIZE[3]         ),
      .AXI_03_AWVALID     (AXI_AWVALID[3]        ),
      .AXI_03_RREADY      (AXI_RREADY[3]         ),
      .AXI_03_BREADY      (AXI_BREADY[3]         ),
      .AXI_03_WDATA       (AXI_WDATA[3]          ),
      .AXI_03_WLAST       (AXI_WLAST[3]          ),
      .AXI_03_WSTRB       (AXI_WSTRB[3]          ),
      .AXI_03_WDATA_PARITY(AXI_WDATA_PARITY_i[3] ),
      .AXI_03_WVALID      (AXI_WVALID[3]         ),
      .AXI_04_ACLK        (AXI_ACLK2_st0_buf     ),
      .AXI_04_ARESET_N    (axi_rst2_st0_n        ),
      .AXI_04_ARADDR      (AXI_ARADDR[4]         ),
      .AXI_04_ARBURST     (AXI_ARBURST[4]        ),
      .AXI_04_ARID        (AXI_ARID[4]           ),
      .AXI_04_ARLEN       (AXI_ARLEN[4][3:0]     ),
      .AXI_04_ARSIZE      (AXI_ARSIZE[4]         ),
      .AXI_04_ARVALID     (AXI_ARVALID[4]        ),
      .AXI_04_AWADDR      (AXI_AWADDR[4]         ),
      .AXI_04_AWBURST     (AXI_AWBURST[4]        ),
      .AXI_04_AWID        (AXI_AWID[4]           ),
      .AXI_04_AWLEN       (AXI_AWLEN[4][3:0]     ),
      .AXI_04_AWSIZE      (AXI_AWSIZE[4]         ),
      .AXI_04_AWVALID     (AXI_AWVALID[4]        ),
      .AXI_04_RREADY      (AXI_RREADY[4]         ),
      .AXI_04_BREADY      (AXI_BREADY[4]         ),
      .AXI_04_WDATA       (AXI_WDATA[4]          ),
      .AXI_04_WLAST       (AXI_WLAST[4]          ),
      .AXI_04_WSTRB       (AXI_WSTRB[4]          ),
      .AXI_04_WDATA_PARITY(AXI_WDATA_PARITY_i[4] ),
      .AXI_04_WVALID      (AXI_WVALID[4]         ),
      .AXI_05_ACLK        (AXI_ACLK2_st0_buf     ),
      .AXI_05_ARESET_N    (axi_rst2_st0_n        ),
      .AXI_05_ARADDR      (AXI_ARADDR[5]         ),
      .AXI_05_ARBURST     (AXI_ARBURST[5]        ),
      .AXI_05_ARID        (AXI_ARID[5]           ),
      .AXI_05_ARLEN       (AXI_ARLEN[5][3:0]     ),
      .AXI_05_ARSIZE      (AXI_ARSIZE[5]         ),
      .AXI_05_ARVALID     (AXI_ARVALID[5]        ),
      .AXI_05_AWADDR      (AXI_AWADDR[5]         ),
      .AXI_05_AWBURST     (AXI_AWBURST[5]        ),
      .AXI_05_AWID        (AXI_AWID[5]           ),
      .AXI_05_AWLEN       (AXI_AWLEN[5][3:0]     ),
      .AXI_05_AWSIZE      (AXI_AWSIZE[5]         ),
      .AXI_05_AWVALID     (AXI_AWVALID[5]        ),
      .AXI_05_RREADY      (AXI_RREADY[5]         ),
      .AXI_05_BREADY      (AXI_BREADY[5]         ),
      .AXI_05_WDATA       (AXI_WDATA[5]          ),
      .AXI_05_WLAST       (AXI_WLAST[5]          ),
      .AXI_05_WSTRB       (AXI_WSTRB[5]          ),
      .AXI_05_WDATA_PARITY(AXI_WDATA_PARITY_i[5] ),
      .AXI_05_WVALID      (AXI_WVALID[5]         ),
      .AXI_06_ACLK        (AXI_ACLK3_st0_buf     ),
      .AXI_06_ARESET_N    (axi_rst3_st0_n        ),
      .AXI_06_ARADDR      (AXI_ARADDR[6]         ),
      .AXI_06_ARBURST     (AXI_ARBURST[6]        ),
      .AXI_06_ARID        (AXI_ARID[6]           ),
      .AXI_06_ARLEN       (AXI_ARLEN[6][3:0]     ),
      .AXI_06_ARSIZE      (AXI_ARSIZE[6]         ),
      .AXI_06_ARVALID     (AXI_ARVALID[6]        ),
      .AXI_06_AWADDR      (AXI_AWADDR[6]         ),
      .AXI_06_AWBURST     (AXI_AWBURST[6]        ),
      .AXI_06_AWID        (AXI_AWID[6]           ),
      .AXI_06_AWLEN       (AXI_AWLEN[6][3:0]     ),
      .AXI_06_AWSIZE      (AXI_AWSIZE[6]         ),
      .AXI_06_AWVALID     (AXI_AWVALID[6]        ),
      .AXI_06_RREADY      (AXI_RREADY[6]         ),
      .AXI_06_BREADY      (AXI_BREADY[6]         ),
      .AXI_06_WDATA       (AXI_WDATA[6]          ),
      .AXI_06_WLAST       (AXI_WLAST[6]          ),
      .AXI_06_WSTRB       (AXI_WSTRB[6]          ),
      .AXI_06_WDATA_PARITY(AXI_WDATA_PARITY_i[6] ),
      .AXI_06_WVALID      (AXI_WVALID[6]         ),
      .AXI_07_ACLK        (AXI_ACLK3_st0_buf     ),
      .AXI_07_ARESET_N    (axi_rst3_st0_n        ),
      .AXI_07_ARADDR      (AXI_ARADDR[7]         ),
      .AXI_07_ARBURST     (AXI_ARBURST[7]        ),
      .AXI_07_ARID        (AXI_ARID[7]           ),
      .AXI_07_ARLEN       (AXI_ARLEN[7][3:0]     ),
      .AXI_07_ARSIZE      (AXI_ARSIZE[7]         ),
      .AXI_07_ARVALID     (AXI_ARVALID[7]        ),
      .AXI_07_AWADDR      (AXI_AWADDR[7]         ),
      .AXI_07_AWBURST     (AXI_AWBURST[7]        ),
      .AXI_07_AWID        (AXI_AWID[7]           ),
      .AXI_07_AWLEN       (AXI_AWLEN[7][3:0]     ),
      .AXI_07_AWSIZE      (AXI_AWSIZE[7]         ),
      .AXI_07_AWVALID     (AXI_AWVALID[7]        ),
      .AXI_07_RREADY      (AXI_RREADY[7]         ),
      .AXI_07_BREADY      (AXI_BREADY[7]         ),
      .AXI_07_WDATA       (AXI_WDATA[7]          ),
      .AXI_07_WLAST       (AXI_WLAST[7]          ),
      .AXI_07_WSTRB       (AXI_WSTRB[7]          ),
      .AXI_07_WDATA_PARITY(AXI_WDATA_PARITY_i[7] ),
      .AXI_07_WVALID      (AXI_WVALID[7]         ),
      .AXI_08_ACLK        (AXI_ACLK4_st0_buf     ),
      .AXI_08_ARESET_N    (axi_rst4_st0_n        ),
      .AXI_08_ARADDR      (AXI_ARADDR[8]         ),
      .AXI_08_ARBURST     (AXI_ARBURST[8]        ),
      .AXI_08_ARID        (AXI_ARID[8]           ),
      .AXI_08_ARLEN       (AXI_ARLEN[8][3:0]     ),
      .AXI_08_ARSIZE      (AXI_ARSIZE[8]         ),
      .AXI_08_ARVALID     (AXI_ARVALID[8]        ),
      .AXI_08_AWADDR      (AXI_AWADDR[8]         ),
      .AXI_08_AWBURST     (AXI_AWBURST[8]        ),
      .AXI_08_AWID        (AXI_AWID[8]           ),
      .AXI_08_AWLEN       (AXI_AWLEN[8][3:0]     ),
      .AXI_08_AWSIZE      (AXI_AWSIZE[8]         ),
      .AXI_08_AWVALID     (AXI_AWVALID[8]        ),
      .AXI_08_RREADY      (AXI_RREADY[8]         ),
      .AXI_08_BREADY      (AXI_BREADY[8]         ),
      .AXI_08_WDATA       (AXI_WDATA[8]          ),
      .AXI_08_WLAST       (AXI_WLAST[8]          ),
      .AXI_08_WSTRB       (AXI_WSTRB[8]          ),
      .AXI_08_WDATA_PARITY(AXI_WDATA_PARITY_i[8] ),
      .AXI_08_WVALID      (AXI_WVALID[8]         ),
      .AXI_09_ACLK        (AXI_ACLK4_st0_buf     ),
      .AXI_09_ARESET_N    (axi_rst4_st0_n        ),
      .AXI_09_ARADDR      (AXI_ARADDR[9]         ),
      .AXI_09_ARBURST     (AXI_ARBURST[9]        ),
      .AXI_09_ARID        (AXI_ARID[9]           ),
      .AXI_09_ARLEN       (AXI_ARLEN[9][3:0]     ),
      .AXI_09_ARSIZE      (AXI_ARSIZE[9]         ),
      .AXI_09_ARVALID     (AXI_ARVALID[9]        ),
      .AXI_09_AWADDR      (AXI_AWADDR[9]         ),
      .AXI_09_AWBURST     (AXI_AWBURST[9]        ),
      .AXI_09_AWID        (AXI_AWID[9]           ),
      .AXI_09_AWLEN       (AXI_AWLEN[9][3:0]     ),
      .AXI_09_AWSIZE      (AXI_AWSIZE[9]         ),
      .AXI_09_AWVALID     (AXI_AWVALID[9]        ),
      .AXI_09_RREADY      (AXI_RREADY[9]         ),
      .AXI_09_BREADY      (AXI_BREADY[9]         ),
      .AXI_09_WDATA       (AXI_WDATA[9]          ),
      .AXI_09_WLAST       (AXI_WLAST[9]          ),
      .AXI_09_WSTRB       (AXI_WSTRB[9]          ),
      .AXI_09_WDATA_PARITY(AXI_WDATA_PARITY_i[9] ),
      .AXI_09_WVALID      (AXI_WVALID[9]         ),
      .AXI_10_ACLK        (AXI_ACLK5_st0_buf     ),
      .AXI_10_ARESET_N    (axi_rst5_st0_n        ),
      .AXI_10_ARADDR      (AXI_ARADDR[10]        ),
      .AXI_10_ARBURST     (AXI_ARBURST[10]       ),
      .AXI_10_ARID        (AXI_ARID[10]          ),
      .AXI_10_ARLEN       (AXI_ARLEN[10][3:0]    ),
      .AXI_10_ARSIZE      (AXI_ARSIZE[10]        ),
      .AXI_10_ARVALID     (AXI_ARVALID[10]       ),
      .AXI_10_AWADDR      (AXI_AWADDR[10]        ),
      .AXI_10_AWBURST     (AXI_AWBURST[10]       ),
      .AXI_10_AWID        (AXI_AWID[10]          ),
      .AXI_10_AWLEN       (AXI_AWLEN[10][3:0]    ),
      .AXI_10_AWSIZE      (AXI_AWSIZE[10]        ),
      .AXI_10_AWVALID     (AXI_AWVALID[10]       ),
      .AXI_10_RREADY      (AXI_RREADY[10]        ),
      .AXI_10_BREADY      (AXI_BREADY[10]        ),
      .AXI_10_WDATA       (AXI_WDATA[10]         ),
      .AXI_10_WLAST       (AXI_WLAST[10]         ),
      .AXI_10_WSTRB       (AXI_WSTRB[10]         ),
      .AXI_10_WDATA_PARITY(AXI_WDATA_PARITY_i[10]),
      .AXI_10_WVALID      (AXI_WVALID[10]        ),
      .AXI_11_ACLK        (AXI_ACLK5_st0_buf     ),
      .AXI_11_ARESET_N    (axi_rst5_st0_n        ),
      .AXI_11_ARADDR      (AXI_ARADDR[11]        ),
      .AXI_11_ARBURST     (AXI_ARBURST[11]       ),
      .AXI_11_ARID        (AXI_ARID[11]          ),
      .AXI_11_ARLEN       (AXI_ARLEN[11][3:0]    ),
      .AXI_11_ARSIZE      (AXI_ARSIZE[11]        ),
      .AXI_11_ARVALID     (AXI_ARVALID[11]       ),
      .AXI_11_AWADDR      (AXI_AWADDR[11]        ),
      .AXI_11_AWBURST     (AXI_AWBURST[11]       ),
      .AXI_11_AWID        (AXI_AWID[11]          ),
      .AXI_11_AWLEN       (AXI_AWLEN[11][3:0]    ),
      .AXI_11_AWSIZE      (AXI_AWSIZE[11]        ),
      .AXI_11_AWVALID     (AXI_AWVALID[11]       ),
      .AXI_11_RREADY      (AXI_RREADY[11]        ),
      .AXI_11_BREADY      (AXI_BREADY[11]        ),
      .AXI_11_WDATA       (AXI_WDATA[11]         ),
      .AXI_11_WLAST       (AXI_WLAST[11]         ),
      .AXI_11_WSTRB       (AXI_WSTRB[11]         ),
      .AXI_11_WDATA_PARITY(AXI_WDATA_PARITY_i[11]),
      .AXI_11_WVALID      (AXI_WVALID[11]        ),
      .AXI_12_ACLK        (AXI_ACLK5_st0_buf     ),
      .AXI_12_ARESET_N    (axi_rst5_st0_n        ),
      .AXI_12_ARADDR      (AXI_ARADDR[12]        ),
      .AXI_12_ARBURST     (AXI_ARBURST[12]       ),
      .AXI_12_ARID        (AXI_ARID[12]          ),
      .AXI_12_ARLEN       (AXI_ARLEN[12][3:0]    ),
      .AXI_12_ARSIZE      (AXI_ARSIZE[12]        ),
      .AXI_12_ARVALID     (AXI_ARVALID[12]       ),
      .AXI_12_AWADDR      (AXI_AWADDR[12]        ),
      .AXI_12_AWBURST     (AXI_AWBURST[12]       ),
      .AXI_12_AWID        (AXI_AWID[12]          ),
      .AXI_12_AWLEN       (AXI_AWLEN[12][3:0]    ),
      .AXI_12_AWSIZE      (AXI_AWSIZE[12]        ),
      .AXI_12_AWVALID     (AXI_AWVALID[12]       ),
      .AXI_12_RREADY      (AXI_RREADY[12]        ),
      .AXI_12_BREADY      (AXI_BREADY[12]        ),
      .AXI_12_WDATA       (AXI_WDATA[12]         ),
      .AXI_12_WLAST       (AXI_WLAST[12]         ),
      .AXI_12_WSTRB       (AXI_WSTRB[12]         ),
      .AXI_12_WDATA_PARITY(AXI_WDATA_PARITY_i[12]),
      .AXI_12_WVALID      (AXI_WVALID[12]        ),
      .AXI_13_ACLK        (AXI_ACLK6_st0_buf     ),
      .AXI_13_ARESET_N    (axi_rst6_st0_n        ),
      .AXI_13_ARADDR      (AXI_ARADDR[13]        ),
      .AXI_13_ARBURST     (AXI_ARBURST[13]       ),
      .AXI_13_ARID        (AXI_ARID[13]          ),
      .AXI_13_ARLEN       (AXI_ARLEN[13][3:0]    ),
      .AXI_13_ARSIZE      (AXI_ARSIZE[13]        ),
      .AXI_13_ARVALID     (AXI_ARVALID[13]       ),
      .AXI_13_AWADDR      (AXI_AWADDR[13]        ),
      .AXI_13_AWBURST     (AXI_AWBURST[13]       ),
      .AXI_13_AWID        (AXI_AWID[13]          ),
      .AXI_13_AWLEN       (AXI_AWLEN[13][3:0]    ),
      .AXI_13_AWSIZE      (AXI_AWSIZE[13]        ),
      .AXI_13_AWVALID     (AXI_AWVALID[13]       ),
      .AXI_13_RREADY      (AXI_RREADY[13]        ),
      .AXI_13_BREADY      (AXI_BREADY[13]        ),
      .AXI_13_WDATA       (AXI_WDATA[13]         ),
      .AXI_13_WLAST       (AXI_WLAST[13]         ),
      .AXI_13_WSTRB       (AXI_WSTRB[13]         ),
      .AXI_13_WDATA_PARITY(AXI_WDATA_PARITY_i[13]),
      .AXI_13_WVALID      (AXI_WVALID[13]        ),
      .AXI_14_ACLK        (AXI_ACLK6_st0_buf     ),
      .AXI_14_ARESET_N    (axi_rst6_st0_n        ),
      .AXI_14_ARADDR      (AXI_ARADDR[14]        ),
      .AXI_14_ARBURST     (AXI_ARBURST[14]       ),
      .AXI_14_ARID        (AXI_ARID[14]          ),
      .AXI_14_ARLEN       (AXI_ARLEN[14][3:0]    ),
      .AXI_14_ARSIZE      (AXI_ARSIZE[14]        ),
      .AXI_14_ARVALID     (AXI_ARVALID[14]       ),
      .AXI_14_AWADDR      (AXI_AWADDR[14]        ),
      .AXI_14_AWBURST     (AXI_AWBURST[14]       ),
      .AXI_14_AWID        (AXI_AWID[14]          ),
      .AXI_14_AWLEN       (AXI_AWLEN[14][3:0]    ),
      .AXI_14_AWSIZE      (AXI_AWSIZE[14]        ),
      .AXI_14_AWVALID     (AXI_AWVALID[14]       ),
      .AXI_14_RREADY      (AXI_RREADY[14]        ),
      .AXI_14_BREADY      (AXI_BREADY[14]        ),
      .AXI_14_WDATA       (AXI_WDATA[14]         ),
      .AXI_14_WLAST       (AXI_WLAST[14]         ),
      .AXI_14_WSTRB       (AXI_WSTRB[14]         ),
      .AXI_14_WDATA_PARITY(AXI_WDATA_PARITY_i[14]),
      .AXI_14_WVALID      (AXI_WVALID[14]        ),
      .AXI_15_ACLK        (AXI_ACLK6_st0_buf     ),
      .AXI_15_ARESET_N    (axi_rst6_st0_n        ),
      .AXI_15_ARADDR      (AXI_ARADDR[15]        ),
      .AXI_15_ARBURST     (AXI_ARBURST[15]       ),
      .AXI_15_ARID        (AXI_ARID[15]          ),
      .AXI_15_ARLEN       (AXI_ARLEN[15][3:0]    ),
      .AXI_15_ARSIZE      (AXI_ARSIZE[15]        ),
      .AXI_15_ARVALID     (AXI_ARVALID[15]       ),
      .AXI_15_AWADDR      (AXI_AWADDR[15]        ),
      .AXI_15_AWBURST     (AXI_AWBURST[15]       ),
      .AXI_15_AWID        (AXI_AWID[15]          ),
      .AXI_15_AWLEN       (AXI_AWLEN[15][3:0]    ),
      .AXI_15_AWSIZE      (AXI_AWSIZE[15]        ),
      .AXI_15_AWVALID     (AXI_AWVALID[15]       ),
      .AXI_15_RREADY      (AXI_RREADY[15]        ),
      .AXI_15_BREADY      (AXI_BREADY[15]        ),
      .AXI_15_WDATA       (AXI_WDATA[15]         ),
      .AXI_15_WLAST       (AXI_WLAST[15]         ),
      .AXI_15_WSTRB       (AXI_WSTRB[15]         ),
      .AXI_15_WDATA_PARITY(AXI_WDATA_PARITY_i[15]),
      .AXI_15_WVALID      (AXI_WVALID[15]        ),

      .APB_0_PWDATA       (APB_0_PWDATA          ),
      .APB_0_PADDR        (APB_0_PADDR           ),
      .APB_0_PCLK         (APB_0_PCLK_BUF        ),
      .APB_0_PENABLE      (APB_0_PENABLE         ),
      .APB_0_PRESET_N     (APB_0_PRESET_N        ),
      .APB_0_PSEL         (APB_0_PSEL            ),
      .APB_0_PWRITE       (APB_0_PWRITE          ),
      .AXI_00_ARREADY     (AXI_ARREADY[0]        ),
      .AXI_00_AWREADY     (AXI_AWREADY[0]        ),
      .AXI_00_RDATA_PARITY(AXI_RDATA_PARITY[0]   ),
      .AXI_00_RDATA       (AXI_RDATA[0]          ),
      .AXI_00_RID         (AXI_RID[0]            ),
      .AXI_00_RLAST       (AXI_RLAST[0]          ),
      .AXI_00_RRESP       (AXI_RRESP[0]          ),
      .AXI_00_RVALID      (AXI_RVALID[0]         ),
      .AXI_00_WREADY      (AXI_WREADY[0]         ),
      .AXI_00_BID         (AXI_BID[0]            ),
      .AXI_00_BRESP       (AXI_BRESP[0]          ),
      .AXI_00_BVALID      (AXI_BVALID[0]         ),
      .AXI_01_ARREADY     (AXI_ARREADY[1]        ),
      .AXI_01_AWREADY     (AXI_AWREADY[1]        ),
      .AXI_01_RDATA_PARITY(AXI_RDATA_PARITY[1]   ),
      .AXI_01_RDATA       (AXI_RDATA[1]          ),
      .AXI_01_RID         (AXI_RID[1]            ),
      .AXI_01_RLAST       (AXI_RLAST[1]          ),
      .AXI_01_RRESP       (AXI_RRESP[1]          ),
      .AXI_01_RVALID      (AXI_RVALID[1]         ),
      .AXI_01_WREADY      (AXI_WREADY[1]         ),
      .AXI_01_BID         (AXI_BID[1]            ),
      .AXI_01_BRESP       (AXI_BRESP[1]          ),
      .AXI_01_BVALID      (AXI_BVALID[1]         ),
      .AXI_02_ARREADY     (AXI_ARREADY[2]        ),
      .AXI_02_AWREADY     (AXI_AWREADY[2]        ),
      .AXI_02_RDATA_PARITY(AXI_RDATA_PARITY[2]   ),
      .AXI_02_RDATA       (AXI_RDATA[2]          ),
      .AXI_02_RID         (AXI_RID[2]            ),
      .AXI_02_RLAST       (AXI_RLAST[2]          ),
      .AXI_02_RRESP       (AXI_RRESP[2]          ),
      .AXI_02_RVALID      (AXI_RVALID[2]         ),
      .AXI_02_WREADY      (AXI_WREADY[2]         ),
      .AXI_02_BID         (AXI_BID[2]            ),
      .AXI_02_BRESP       (AXI_BRESP[2]          ),
      .AXI_02_BVALID      (AXI_BVALID[2]         ),
      .AXI_03_ARREADY     (AXI_ARREADY[3]        ),
      .AXI_03_AWREADY     (AXI_AWREADY[3]        ),
      .AXI_03_RDATA_PARITY(AXI_RDATA_PARITY[3]   ),
      .AXI_03_RDATA       (AXI_RDATA[3]          ),
      .AXI_03_RID         (AXI_RID[3]            ),
      .AXI_03_RLAST       (AXI_RLAST[3]          ),
      .AXI_03_RRESP       (AXI_RRESP[3]          ),
      .AXI_03_RVALID      (AXI_RVALID[3]         ),
      .AXI_03_WREADY      (AXI_WREADY[3]         ),
      .AXI_03_BID         (AXI_BID[3]            ),
      .AXI_03_BRESP       (AXI_BRESP[3]          ),
      .AXI_03_BVALID      (AXI_BVALID[3]         ),
      .AXI_04_ARREADY     (AXI_ARREADY[4]        ),
      .AXI_04_AWREADY     (AXI_AWREADY[4]        ),
      .AXI_04_RDATA_PARITY(AXI_RDATA_PARITY[4]   ),
      .AXI_04_RDATA       (AXI_RDATA[4]          ),
      .AXI_04_RID         (AXI_RID[4]            ),
      .AXI_04_RLAST       (AXI_RLAST[4]          ),
      .AXI_04_RRESP       (AXI_RRESP[4]          ),
      .AXI_04_RVALID      (AXI_RVALID[4]         ),
      .AXI_04_WREADY      (AXI_WREADY[4]         ),
      .AXI_04_BID         (AXI_BID[4]            ),
      .AXI_04_BRESP       (AXI_BRESP[4]          ),
      .AXI_04_BVALID      (AXI_BVALID[4]         ),
      .AXI_05_ARREADY     (AXI_ARREADY[5]        ),
      .AXI_05_AWREADY     (AXI_AWREADY[5]        ),
      .AXI_05_RDATA_PARITY(AXI_RDATA_PARITY[5]   ),
      .AXI_05_RDATA       (AXI_RDATA[5]          ),
      .AXI_05_RID         (AXI_RID[5]            ),
      .AXI_05_RLAST       (AXI_RLAST[5]          ),
      .AXI_05_RRESP       (AXI_RRESP[5]          ),
      .AXI_05_RVALID      (AXI_RVALID[5]         ),
      .AXI_05_WREADY      (AXI_WREADY[5]         ),
      .AXI_05_BID         (AXI_BID[5]            ),
      .AXI_05_BRESP       (AXI_BRESP[5]          ),
      .AXI_05_BVALID      (AXI_BVALID[5]         ),
      .AXI_06_ARREADY     (AXI_ARREADY[6]        ),
      .AXI_06_AWREADY     (AXI_AWREADY[6]        ),
      .AXI_06_RDATA_PARITY(AXI_RDATA_PARITY[6]   ),
      .AXI_06_RDATA       (AXI_RDATA[6]          ),
      .AXI_06_RID         (AXI_RID[6]            ),
      .AXI_06_RLAST       (AXI_RLAST[6]          ),
      .AXI_06_RRESP       (AXI_RRESP[6]          ),
      .AXI_06_RVALID      (AXI_RVALID[6]         ),
      .AXI_06_WREADY      (AXI_WREADY[6]         ),
      .AXI_06_BID         (AXI_BID[6]            ),
      .AXI_06_BRESP       (AXI_BRESP[6]          ),
      .AXI_06_BVALID      (AXI_BVALID[6]         ),
      .AXI_07_ARREADY     (AXI_ARREADY[7]        ),
      .AXI_07_AWREADY     (AXI_AWREADY[7]        ),
      .AXI_07_RDATA_PARITY(AXI_RDATA_PARITY[7]   ),
      .AXI_07_RDATA       (AXI_RDATA[7]          ),
      .AXI_07_RID         (AXI_RID[7]            ),
      .AXI_07_RLAST       (AXI_RLAST[7]          ),
      .AXI_07_RRESP       (AXI_RRESP[7]          ),
      .AXI_07_RVALID      (AXI_RVALID[7]         ),
      .AXI_07_WREADY      (AXI_WREADY[7]         ),
      .AXI_07_BID         (AXI_BID[7]            ),
      .AXI_07_BRESP       (AXI_BRESP[7]          ),
      .AXI_07_BVALID      (AXI_BVALID[7]         ),
      .AXI_08_ARREADY     (AXI_ARREADY[8]        ),
      .AXI_08_AWREADY     (AXI_AWREADY[8]        ),
      .AXI_08_RDATA_PARITY(AXI_RDATA_PARITY[8]   ),
      .AXI_08_RDATA       (AXI_RDATA[8]          ),
      .AXI_08_RID         (AXI_RID[8]            ),
      .AXI_08_RLAST       (AXI_RLAST[8]          ),
      .AXI_08_RRESP       (AXI_RRESP[8]          ),
      .AXI_08_RVALID      (AXI_RVALID[8]         ),
      .AXI_08_WREADY      (AXI_WREADY[8]         ),
      .AXI_08_BID         (AXI_BID[8]            ),
      .AXI_08_BRESP       (AXI_BRESP[8]          ),
      .AXI_08_BVALID      (AXI_BVALID[8]         ),
      .AXI_09_ARREADY     (AXI_ARREADY[9]        ),
      .AXI_09_AWREADY     (AXI_AWREADY[9]        ),
      .AXI_09_RDATA_PARITY(AXI_RDATA_PARITY[9]   ),
      .AXI_09_RDATA       (AXI_RDATA[9]          ),
      .AXI_09_RID         (AXI_RID[9]            ),
      .AXI_09_RLAST       (AXI_RLAST[9]          ),
      .AXI_09_RRESP       (AXI_RRESP[9]          ),
      .AXI_09_RVALID      (AXI_RVALID[9]         ),
      .AXI_09_WREADY      (AXI_WREADY[9]         ),
      .AXI_09_BID         (AXI_BID[9]            ),
      .AXI_09_BRESP       (AXI_BRESP[9]          ),
      .AXI_09_BVALID      (AXI_BVALID[9]         ),
      .AXI_10_ARREADY     (AXI_ARREADY[10]       ),
      .AXI_10_AWREADY     (AXI_AWREADY[10]       ),
      .AXI_10_RDATA_PARITY(AXI_RDATA_PARITY[10]  ),
      .AXI_10_RDATA       (AXI_RDATA[10]         ),
      .AXI_10_RID         (AXI_RID[10]           ),
      .AXI_10_RLAST       (AXI_RLAST[10]         ),
      .AXI_10_RRESP       (AXI_RRESP[10]         ),
      .AXI_10_RVALID      (AXI_RVALID[10]        ),
      .AXI_10_WREADY      (AXI_WREADY[10]        ),
      .AXI_10_BID         (AXI_BID[10]           ),
      .AXI_10_BRESP       (AXI_BRESP[10]         ),
      .AXI_10_BVALID      (AXI_BVALID[10]        ),
      .AXI_11_ARREADY     (AXI_ARREADY[11]       ),
      .AXI_11_AWREADY     (AXI_AWREADY[11]       ),
      .AXI_11_RDATA_PARITY(AXI_RDATA_PARITY[11]  ),
      .AXI_11_RDATA       (AXI_RDATA[11]         ),
      .AXI_11_RID         (AXI_RID[11]           ),
      .AXI_11_RLAST       (AXI_RLAST[11]         ),
      .AXI_11_RRESP       (AXI_RRESP[11]         ),
      .AXI_11_RVALID      (AXI_RVALID[11]        ),
      .AXI_11_WREADY      (AXI_WREADY[11]        ),
      .AXI_11_BID         (AXI_BID[11]           ),
      .AXI_11_BRESP       (AXI_BRESP[11]         ),
      .AXI_11_BVALID      (AXI_BVALID[11]        ),
      .AXI_12_ARREADY     (AXI_ARREADY[12]       ),
      .AXI_12_AWREADY     (AXI_AWREADY[12]       ),
      .AXI_12_RDATA_PARITY(AXI_RDATA_PARITY[12]  ),
      .AXI_12_RDATA       (AXI_RDATA[12]         ),
      .AXI_12_RID         (AXI_RID[12]           ),
      .AXI_12_RLAST       (AXI_RLAST[12]         ),
      .AXI_12_RRESP       (AXI_RRESP[12]         ),
      .AXI_12_RVALID      (AXI_RVALID[12]        ),
      .AXI_12_WREADY      (AXI_WREADY[12]        ),
      .AXI_12_BID         (AXI_BID[12]           ),
      .AXI_12_BRESP       (AXI_BRESP[12]         ),
      .AXI_12_BVALID      (AXI_BVALID[12]        ),
      .AXI_13_ARREADY     (AXI_ARREADY[13]       ),
      .AXI_13_AWREADY     (AXI_AWREADY[13]       ),
      .AXI_13_RDATA_PARITY(AXI_RDATA_PARITY[13]  ),
      .AXI_13_RDATA       (AXI_RDATA[13]         ),
      .AXI_13_RID         (AXI_RID[13]           ),
      .AXI_13_RLAST       (AXI_RLAST[13]         ),
      .AXI_13_RRESP       (AXI_RRESP[13]         ),
      .AXI_13_RVALID      (AXI_RVALID[13]        ),
      .AXI_13_WREADY      (AXI_WREADY[13]        ),
      .AXI_13_BID         (AXI_BID[13]           ),
      .AXI_13_BRESP       (AXI_BRESP[13]         ),
      .AXI_13_BVALID      (AXI_BVALID[13]        ),
      .AXI_14_ARREADY     (AXI_ARREADY[14]       ),
      .AXI_14_AWREADY     (AXI_AWREADY[14]       ),
      .AXI_14_RDATA_PARITY(AXI_RDATA_PARITY[14]  ),
      .AXI_14_RDATA       (AXI_RDATA[14]         ),
      .AXI_14_RID         (AXI_RID[14]           ),
      .AXI_14_RLAST       (AXI_RLAST[14]         ),
      .AXI_14_RRESP       (AXI_RRESP[14]         ),
      .AXI_14_RVALID      (AXI_RVALID[14]        ),
      .AXI_14_WREADY      (AXI_WREADY[14]        ),
      .AXI_14_BID         (AXI_BID[14]           ),
      .AXI_14_BRESP       (AXI_BRESP[14]         ),
      .AXI_14_BVALID      (AXI_BVALID[14]        ),
      .AXI_15_ARREADY     (AXI_ARREADY[15]       ),
      .AXI_15_AWREADY     (AXI_AWREADY[15]       ),
      .AXI_15_RDATA_PARITY(AXI_RDATA_PARITY[15]  ),
      .AXI_15_RDATA       (AXI_RDATA[15]         ),
      .AXI_15_RID         (AXI_RID[15]           ),
      .AXI_15_RLAST       (AXI_RLAST[15]         ),
      .AXI_15_RRESP       (AXI_RRESP[15]         ),
      .AXI_15_RVALID      (AXI_RVALID[15]        ),
      .AXI_15_WREADY      (AXI_WREADY[15]        ),
      .AXI_15_BID         (AXI_BID[15]           ),
      .AXI_15_BRESP       (AXI_BRESP[15]         ),
      .AXI_15_BVALID      (AXI_BVALID[15]        ),
      .apb_complete_0     (apb_seq_complete_0_s  ),
      .APB_0_PRDATA       (APB_0_PRDATA          ),
      .APB_0_PREADY       (APB_0_PREADY          ),
      .APB_0_PSLVERR      (APB_0_PSLVERR         ),

      .DRAM_0_STAT_CATTRIP(DRAM_0_STAT_CATTRIP   ),
      .DRAM_0_STAT_TEMP   (DRAM_0_STAT_TEMP      )
    );

  end // lv3_hbm

  else begin : noop
  end : noop

endmodule
