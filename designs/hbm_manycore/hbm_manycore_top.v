/*
* hbm_manycore_top.v
*
* top level of the F1_manycore design on local FPGA
*/

// board specific headers
//`include "bsg_fpga_board_pkg.v"
`include "bsg_axi_bus_pkg.vh"
`include "bsg_bladerunner_defines.vh"
//`include "cl_manycore_pkg.v"
//`include "bsg_bladerunner_mem_cfg_pkg.v"

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


  `ifdef FPGA_TARGET_ULTRASCALE_PLUS
    `ifdef FPGA_TARGET_HBM
      localparam DEVICE_FAMILY = "virtexuplushbm";
    `else
      localparam DEVICE_FAMILY = "virtexuplus"
    `endif
  `endif

  `declare_bsg_axi4_bus_s(1, pcie_axi_id_width_p, pcie_axi_addr_width_p, pcie_axi_data_width_p,
                          bsg_axi4_pcie_mosi_s, bsg_axi4_pcie_miso_s);

  `declare_bsg_axi4_bus_s(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p,
                          bsg_axi4_mosi_bus_s, bsg_axi4_miso_bus_s);

  `declare_bsg_axi4_bus_s(1, axi_id_width_p, axi_addr_width_p, hbm_data_width_lp,
                          bsg_axi4_hbm_si_s, bsg_axi4_hbm_mo_s);

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
    .clk_out1 (APB_0_PCLK_IBUF ),
    .clk_out2 (hbm_axil_clk_int),
    .clk_out3 (hbm_ref_clk_int ),
    // Status and control signals
    .reset    (1'b0            ),
    .locked   (locked_pll[0]   ),
    // Clock in ports
    .clk_in1_p(mem_clk_i_p     ),
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

  qcl_breath_en #(.val_p('d50000000)) led_breath_rst (
    .clk_i  (hbm_axil_clk_int),
    .reset_i(1'b0            ),
    .en_i   (1'b1            ),
    .o      (leds_o[4]        )
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
  qcl_debounce #(.width_p(22)) reset_debounce (
    .clk_i(clk_axi4_pcie_li),
    .i    (ext_btn_reset_i),
    .o    (ext_reset_dbnc )
  );

  // manycore reset
  // TODO: add system hard reset
  wire mc_reset_i = (ext_reset_dbnc  | ~rstn_axi4_pcie_li);

  // hbm system reset
  wire APB_0_PRESET_N = ~ext_reset_dbnc;
  wire AXI_ARESET_N_0 = ~ext_reset_dbnc;

  wire axi_trans_err;
  assign leds_o[5] = ~(&locked_pll);

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

  // LEDs for pcie observation
  assign leds_o[0] = sys_rst_n_buf_lo;
  assign leds_o[1] = rstn_axi4_pcie_li;
  assign leds_o[2] = user_link_up_lo;
  assign leds_o[3] = user_clk_heartbeat[26];


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

  bsg_axil_mosi_bus_s s_axil_mc_li;
  bsg_axil_miso_bus_s s_axil_mc_lo;

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
    .m_axi_awaddr (s_axil_mc_li.awaddr  ),
    .m_axi_awprot (                     ),
    .m_axi_awvalid(s_axil_mc_li.awvalid ),
    .m_axi_awready(s_axil_mc_lo.awready ),
    .m_axi_wdata  (s_axil_mc_li.wdata   ),
    .m_axi_wstrb  (s_axil_mc_li.wstrb   ),
    .m_axi_wvalid (s_axil_mc_li.wvalid  ),
    .m_axi_wready (s_axil_mc_lo.wready  ),
    .m_axi_bresp  (s_axil_mc_lo.bresp   ),
    .m_axi_bvalid (s_axil_mc_lo.bvalid  ),
    .m_axi_bready (s_axil_mc_li.bready  ),
    .m_axi_araddr (s_axil_mc_li.araddr  ),
    .m_axi_arvalid(s_axil_mc_li.arvalid ),
    .m_axi_arready(s_axil_mc_lo.arready ),
    .m_axi_rdata  (s_axil_mc_lo.rdata   ),
    .m_axi_rresp  (s_axil_mc_lo.rresp   ),
    .m_axi_rvalid (s_axil_mc_lo.rvalid  ),
    .m_axi_rready (s_axil_mc_li.rready  )
  );

  // ---------------------------------------------
  // axil traffic monitor LEDs
  // ---------------------------------------------
  wire axil_wr_issued = s_axil_mc_li.wvalid & s_axil_mc_lo.wready;
  wire axil_rd_issued = s_axil_mc_lo.rvalid & s_axil_mc_li.rready;

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

  localparam num_axi_slot_lp = (mem_cfg_p == e_vcache_blocking_axi4_xbar_dram ||
                                mem_cfg_p == e_vcache_blocking_axi4_xbar_model ||
                                mem_cfg_p == e_vcache_blocking_axi4_hbm) ?
                                num_tiles_x_p : 1;

  bsg_axi4_mosi_bus_s [num_axi_slot_lp-1:0] mc_axi4_cache_lo;
  bsg_axi4_miso_bus_s [num_axi_slot_lp-1:0] mc_axi4_cache_li;

  // hb_manycore
  bsg_bladerunner_wrapper #(.num_axi_slot_p(num_axi_slot_lp)) hb_mc_wrapper (
    .clk_i       (clk_axi4_pcie_li),
    .reset_i     (mc_reset_i      ),
    .clk2_i      (clk_axi4_pcie_li),
    .reset2_i    (mc_reset_i      ),
    // AXI-Lite
    .s_axil_bus_i(s_axil_mc_li    ),
    .s_axil_bus_o(s_axil_mc_lo    ),
    // AXI4 Master
    .m_axi4_bus_o(mc_axi4_cache_lo),
    .m_axi4_bus_i(mc_axi4_cache_li)
  );

  bsg_axi4_mosi_bus_s [num_axi_slot_lp-1:0] s_axi4_cdc_li, m_axi4_cdc_lo;
  bsg_axi4_miso_bus_s [num_axi_slot_lp-1:0] s_axi4_cdc_lo, m_axi4_cdc_li;

  assign s_axi4_cdc_li = mc_axi4_cache_lo;
  assign mc_axi4_cache_li = s_axi4_cdc_lo;

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
      .id_width_p        (axi_id_width_p  ),
      .addr_width_p      (axi_addr_width_p),
      .data_width_p      (axi_data_width_p),
      .device_family     (DEVICE_FAMILY   ),
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
  else if (mem_cfg_p == e_vcache_blocking_axi4_hbm) begin : lv3_hbm

    for (genvar i = 0; i < num_axi_slot_lp; i++) begin : axi_dv_cvt
      always_comb begin : hbm_addr_map
        axi4_hbm_chs_li[i] = m_axi4_cdc_lo[i];
        axi4_hbm_chs_li[i].awaddr[0][32:0] = m_axi4_cdc_lo[i].awaddr[0][31:0] | 33'(i<<28); // we are using 4H stack, tell from example
        axi4_hbm_chs_li[i].araddr[0][32:0] = m_axi4_cdc_lo[i].araddr[0][31:0] | 33'(i<<28);
        m_axi4_cdc_li[i] = axi4_hbm_chs_lo[i];
      end : hbm_addr_map
    end : axi_dv_cvt

    // for (genvar i = num_axi_slot_lp; i < num_hbm_chs_lp; i++) begin : tie_off_hbm_axi4
    //   assign axi4_hbm_chs_li[i] = '0; // to hbm_channels
    //   // assign axi4_hbm_chs_lo_cast = axi4_hbm_chs_lo
    // end : tie_off_hbm_axi4


  wire          apb_seq_complete_0_s;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_0_st0_r0, apb_seq_complete_0_st0_r1, apb_seq_complete_0_st0_r2;
  wire          tg_start_st0_0;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_1_st0_r0, apb_seq_complete_1_st0_r1, apb_seq_complete_1_st0_r2;
  wire          tg_start_st0_1;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_2_st0_r0, apb_seq_complete_2_st0_r1, apb_seq_complete_2_st0_r2;
  wire          tg_start_st0_2;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_3_st0_r0, apb_seq_complete_3_st0_r1, apb_seq_complete_3_st0_r2;
  wire          tg_start_st0_3;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_4_st0_r0, apb_seq_complete_4_st0_r1, apb_seq_complete_4_st0_r2;
  wire          tg_start_st0_4;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_5_st0_r0, apb_seq_complete_5_st0_r1, apb_seq_complete_5_st0_r2;
  wire          tg_start_st0_5;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_6_st0_r0, apb_seq_complete_6_st0_r1, apb_seq_complete_6_st0_r2;
  wire          tg_start_st0_6;

  wire              ext_apb_seq_complete_s;
  wire              ext_apb_seq_complete_0_int_s;
  wire              ext_apb_seq_complete_0_s;
`ifndef SIMULATION_MODE
  wire     [ 31:0]  APB_0_PWDATA = 32'b0;
  wire     [ 21:0]  APB_0_PADDR  = 22'b0;
  wire              APB_0_PENABLE = 1'b0;
  wire              APB_0_PSEL = 1'b0;
  wire              APB_0_PWRITE = 1'b0;
  wire     [ 31:0]  APB_0_PRDATA;
  wire              APB_0_PREADY;
  wire              APB_0_PSLVERR;
`endif

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_0;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_0;
  wire [ 32:0]  AXI_00_ARADDR;
  wire [  1:0]  AXI_00_ARBURST;
  wire [  5:0]  AXI_00_ARID;
  wire [  7:0]  AXI_00_ARLEN;
  wire [  2:0]  AXI_00_ARSIZE;
  wire          AXI_00_ARVALID;
  wire [ 32:0]  AXI_00_AWADDR;
  wire [  1:0]  AXI_00_AWBURST;
  wire [  5:0]  AXI_00_AWID;
  wire [  7:0]  AXI_00_AWLEN;
  wire [  2:0]  AXI_00_AWSIZE;
  wire          AXI_00_AWVALID;
  wire          AXI_00_RREADY;
  wire          AXI_00_BREADY;
  wire [255:0]  AXI_00_WDATA;
  wire          AXI_00_WLAST;
  wire [ 31:0]  AXI_00_WSTRB;
  wire [ 31:0]  AXI_00_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_00_WDATA_PARITY;
  wire          AXI_00_WVALID;
  wire [3:0]    AXI_00_ARCACHE;
  wire [3:0]    AXI_00_AWCACHE;
  wire [2:0]    AXI_00_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_0;
`endif
  wire      [31:0]  prbs_mode_seed_0 = 32'habcd_1234;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_1;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_1;
  wire [ 32:0]  AXI_01_ARADDR;
  wire [  1:0]  AXI_01_ARBURST;
  wire [  5:0]  AXI_01_ARID;
  wire [  7:0]  AXI_01_ARLEN;
  wire [  2:0]  AXI_01_ARSIZE;
  wire          AXI_01_ARVALID;
  wire [ 32:0]  AXI_01_AWADDR;
  wire [  1:0]  AXI_01_AWBURST;
  wire [  5:0]  AXI_01_AWID;
  wire [  7:0]  AXI_01_AWLEN;
  wire [  2:0]  AXI_01_AWSIZE;
  wire          AXI_01_AWVALID;
  wire          AXI_01_RREADY;
  wire          AXI_01_BREADY;
  wire [255:0]  AXI_01_WDATA;
  wire          AXI_01_WLAST;
  wire [ 31:0]  AXI_01_WSTRB;
  wire [ 31:0]  AXI_01_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_01_WDATA_PARITY;
  wire          AXI_01_WVALID;
  wire [3:0]    AXI_01_ARCACHE;
  wire [3:0]    AXI_01_AWCACHE;
  wire [2:0]    AXI_01_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_1;
`endif
  wire      [31:0]  prbs_mode_seed_1 = 32'habcd_1234;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_2;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_2;
  wire [ 32:0]  AXI_02_ARADDR;
  wire [  1:0]  AXI_02_ARBURST;
  wire [  5:0]  AXI_02_ARID;
  wire [  7:0]  AXI_02_ARLEN;
  wire [  2:0]  AXI_02_ARSIZE;
  wire          AXI_02_ARVALID;
  wire [ 32:0]  AXI_02_AWADDR;
  wire [  1:0]  AXI_02_AWBURST;
  wire [  5:0]  AXI_02_AWID;
  wire [  7:0]  AXI_02_AWLEN;
  wire [  2:0]  AXI_02_AWSIZE;
  wire          AXI_02_AWVALID;
  wire          AXI_02_RREADY;
  wire          AXI_02_BREADY;
  wire [255:0]  AXI_02_WDATA;
  wire          AXI_02_WLAST;
  wire [ 31:0]  AXI_02_WSTRB;
  wire [ 31:0]  AXI_02_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_02_WDATA_PARITY;
  wire          AXI_02_WVALID;
  wire [3:0]    AXI_02_ARCACHE;
  wire [3:0]    AXI_02_AWCACHE;
  wire [2:0]    AXI_02_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_2;
`endif
  wire      [31:0]  prbs_mode_seed_2 = 32'habcd_1234;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_3;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_3;
  wire [ 32:0]  AXI_03_ARADDR;
  wire [  1:0]  AXI_03_ARBURST;
  wire [  5:0]  AXI_03_ARID;
  wire [  7:0]  AXI_03_ARLEN;
  wire [  2:0]  AXI_03_ARSIZE;
  wire          AXI_03_ARVALID;
  wire [ 32:0]  AXI_03_AWADDR;
  wire [  1:0]  AXI_03_AWBURST;
  wire [  5:0]  AXI_03_AWID;
  wire [  7:0]  AXI_03_AWLEN;
  wire [  2:0]  AXI_03_AWSIZE;
  wire          AXI_03_AWVALID;
  wire          AXI_03_RREADY;
  wire          AXI_03_BREADY;
  wire [255:0]  AXI_03_WDATA;
  wire          AXI_03_WLAST;
  wire [ 31:0]  AXI_03_WSTRB;
  wire [ 31:0]  AXI_03_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_03_WDATA_PARITY;
  wire          AXI_03_WVALID;
  wire [3:0]    AXI_03_ARCACHE;
  wire [3:0]    AXI_03_AWCACHE;
  wire [2:0]    AXI_03_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_3;
`endif
  wire      [31:0]  prbs_mode_seed_3 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_4;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_4;
  wire [ 32:0]  AXI_04_ARADDR;
  wire [  1:0]  AXI_04_ARBURST;
  wire [  5:0]  AXI_04_ARID;
  wire [  7:0]  AXI_04_ARLEN;
  wire [  2:0]  AXI_04_ARSIZE;
  wire          AXI_04_ARVALID;
  wire [ 32:0]  AXI_04_AWADDR;
  wire [  1:0]  AXI_04_AWBURST;
  wire [  5:0]  AXI_04_AWID;
  wire [  7:0]  AXI_04_AWLEN;
  wire [  2:0]  AXI_04_AWSIZE;
  wire          AXI_04_AWVALID;
  wire          AXI_04_RREADY;
  wire          AXI_04_BREADY;
  wire [255:0]  AXI_04_WDATA;
  wire          AXI_04_WLAST;
  wire [ 31:0]  AXI_04_WSTRB;
  wire [ 31:0]  AXI_04_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_04_WDATA_PARITY;
  wire          AXI_04_WVALID;
  wire [3:0]    AXI_04_ARCACHE;
  wire [3:0]    AXI_04_AWCACHE;
  wire [2:0]    AXI_04_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_4;
`endif
  wire      [31:0]  prbs_mode_seed_4 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_5;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_5;
  wire [ 32:0]  AXI_05_ARADDR;
  wire [  1:0]  AXI_05_ARBURST;
  wire [  5:0]  AXI_05_ARID;
  wire [  7:0]  AXI_05_ARLEN;
  wire [  2:0]  AXI_05_ARSIZE;
  wire          AXI_05_ARVALID;
  wire [ 32:0]  AXI_05_AWADDR;
  wire [  1:0]  AXI_05_AWBURST;
  wire [  5:0]  AXI_05_AWID;
  wire [  7:0]  AXI_05_AWLEN;
  wire [  2:0]  AXI_05_AWSIZE;
  wire          AXI_05_AWVALID;
  wire          AXI_05_RREADY;
  wire          AXI_05_BREADY;
  wire [255:0]  AXI_05_WDATA;
  wire          AXI_05_WLAST;
  wire [ 31:0]  AXI_05_WSTRB;
  wire [ 31:0]  AXI_05_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_05_WDATA_PARITY;
  wire          AXI_05_WVALID;
  wire [3:0]    AXI_05_ARCACHE;
  wire [3:0]    AXI_05_AWCACHE;
  wire [2:0]    AXI_05_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_5;
`endif
  wire      [31:0]  prbs_mode_seed_5 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_6;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_6;
  wire [ 32:0]  AXI_06_ARADDR;
  wire [  1:0]  AXI_06_ARBURST;
  wire [  5:0]  AXI_06_ARID;
  wire [  7:0]  AXI_06_ARLEN;
  wire [  2:0]  AXI_06_ARSIZE;
  wire          AXI_06_ARVALID;
  wire [ 32:0]  AXI_06_AWADDR;
  wire [  1:0]  AXI_06_AWBURST;
  wire [  5:0]  AXI_06_AWID;
  wire [  7:0]  AXI_06_AWLEN;
  wire [  2:0]  AXI_06_AWSIZE;
  wire          AXI_06_AWVALID;
  wire          AXI_06_RREADY;
  wire          AXI_06_BREADY;
  wire [255:0]  AXI_06_WDATA;
  wire          AXI_06_WLAST;
  wire [ 31:0]  AXI_06_WSTRB;
  wire [ 31:0]  AXI_06_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_06_WDATA_PARITY;
  wire          AXI_06_WVALID;
  wire [3:0]    AXI_06_ARCACHE;
  wire [3:0]    AXI_06_AWCACHE;
  wire [2:0]    AXI_06_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_6;
`endif
  wire      [31:0]  prbs_mode_seed_6 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_7;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_7;
  wire [ 32:0]  AXI_07_ARADDR;
  wire [  1:0]  AXI_07_ARBURST;
  wire [  5:0]  AXI_07_ARID;
  wire [  7:0]  AXI_07_ARLEN;
  wire [  2:0]  AXI_07_ARSIZE;
  wire          AXI_07_ARVALID;
  wire [ 32:0]  AXI_07_AWADDR;
  wire [  1:0]  AXI_07_AWBURST;
  wire [  5:0]  AXI_07_AWID;
  wire [  7:0]  AXI_07_AWLEN;
  wire [  2:0]  AXI_07_AWSIZE;
  wire          AXI_07_AWVALID;
  wire          AXI_07_RREADY;
  wire          AXI_07_BREADY;
  wire [255:0]  AXI_07_WDATA;
  wire          AXI_07_WLAST;
  wire [ 31:0]  AXI_07_WSTRB;
  wire [ 31:0]  AXI_07_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_07_WDATA_PARITY;
  wire          AXI_07_WVALID;
  wire [3:0]    AXI_07_ARCACHE;
  wire [3:0]    AXI_07_AWCACHE;
  wire [2:0]    AXI_07_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_7;
`endif
  wire      [31:0]  prbs_mode_seed_7 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_8;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_8;
  wire [ 32:0]  AXI_08_ARADDR;
  wire [  1:0]  AXI_08_ARBURST;
  wire [  5:0]  AXI_08_ARID;
  wire [  7:0]  AXI_08_ARLEN;
  wire [  2:0]  AXI_08_ARSIZE;
  wire          AXI_08_ARVALID;
  wire [ 32:0]  AXI_08_AWADDR;
  wire [  1:0]  AXI_08_AWBURST;
  wire [  5:0]  AXI_08_AWID;
  wire [  7:0]  AXI_08_AWLEN;
  wire [  2:0]  AXI_08_AWSIZE;
  wire          AXI_08_AWVALID;
  wire          AXI_08_RREADY;
  wire          AXI_08_BREADY;
  wire [255:0]  AXI_08_WDATA;
  wire          AXI_08_WLAST;
  wire [ 31:0]  AXI_08_WSTRB;
  wire [ 31:0]  AXI_08_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_08_WDATA_PARITY;
  wire          AXI_08_WVALID;
  wire [3:0]    AXI_08_ARCACHE;
  wire [3:0]    AXI_08_AWCACHE;
  wire [2:0]    AXI_08_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_8;
`endif
  wire      [31:0]  prbs_mode_seed_8 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_9;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_9;
  wire [ 32:0]  AXI_09_ARADDR;
  wire [  1:0]  AXI_09_ARBURST;
  wire [  5:0]  AXI_09_ARID;
  wire [  7:0]  AXI_09_ARLEN;
  wire [  2:0]  AXI_09_ARSIZE;
  wire          AXI_09_ARVALID;
  wire [ 32:0]  AXI_09_AWADDR;
  wire [  1:0]  AXI_09_AWBURST;
  wire [  5:0]  AXI_09_AWID;
  wire [  7:0]  AXI_09_AWLEN;
  wire [  2:0]  AXI_09_AWSIZE;
  wire          AXI_09_AWVALID;
  wire          AXI_09_RREADY;
  wire          AXI_09_BREADY;
  wire [255:0]  AXI_09_WDATA;
  wire          AXI_09_WLAST;
  wire [ 31:0]  AXI_09_WSTRB;
  wire [ 31:0]  AXI_09_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_09_WDATA_PARITY;
  wire          AXI_09_WVALID;
  wire [3:0]    AXI_09_ARCACHE;
  wire [3:0]    AXI_09_AWCACHE;
  wire [2:0]    AXI_09_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_9;
`endif
  wire      [31:0]  prbs_mode_seed_9 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_10;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_10;
  wire [ 32:0]  AXI_10_ARADDR;
  wire [  1:0]  AXI_10_ARBURST;
  wire [  5:0]  AXI_10_ARID;
  wire [  7:0]  AXI_10_ARLEN;
  wire [  2:0]  AXI_10_ARSIZE;
  wire          AXI_10_ARVALID;
  wire [ 32:0]  AXI_10_AWADDR;
  wire [  1:0]  AXI_10_AWBURST;
  wire [  5:0]  AXI_10_AWID;
  wire [  7:0]  AXI_10_AWLEN;
  wire [  2:0]  AXI_10_AWSIZE;
  wire          AXI_10_AWVALID;
  wire          AXI_10_RREADY;
  wire          AXI_10_BREADY;
  wire [255:0]  AXI_10_WDATA;
  wire          AXI_10_WLAST;
  wire [ 31:0]  AXI_10_WSTRB;
  wire [ 31:0]  AXI_10_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_10_WDATA_PARITY;
  wire          AXI_10_WVALID;
  wire [3:0]    AXI_10_ARCACHE;
  wire [3:0]    AXI_10_AWCACHE;
  wire [2:0]    AXI_10_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_10;
`endif
  wire      [31:0]  prbs_mode_seed_10 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_11;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_11;
  wire [ 32:0]  AXI_11_ARADDR;
  wire [  1:0]  AXI_11_ARBURST;
  wire [  5:0]  AXI_11_ARID;
  wire [  7:0]  AXI_11_ARLEN;
  wire [  2:0]  AXI_11_ARSIZE;
  wire          AXI_11_ARVALID;
  wire [ 32:0]  AXI_11_AWADDR;
  wire [  1:0]  AXI_11_AWBURST;
  wire [  5:0]  AXI_11_AWID;
  wire [  7:0]  AXI_11_AWLEN;
  wire [  2:0]  AXI_11_AWSIZE;
  wire          AXI_11_AWVALID;
  wire          AXI_11_RREADY;
  wire          AXI_11_BREADY;
  wire [255:0]  AXI_11_WDATA;
  wire          AXI_11_WLAST;
  wire [ 31:0]  AXI_11_WSTRB;
  wire [ 31:0]  AXI_11_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_11_WDATA_PARITY;
  wire          AXI_11_WVALID;
  wire [3:0]    AXI_11_ARCACHE;
  wire [3:0]    AXI_11_AWCACHE;
  wire [2:0]    AXI_11_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_11;
`endif
  wire      [31:0]  prbs_mode_seed_11 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_12;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_12;
  wire [ 32:0]  AXI_12_ARADDR;
  wire [  1:0]  AXI_12_ARBURST;
  wire [  5:0]  AXI_12_ARID;
  wire [  7:0]  AXI_12_ARLEN;
  wire [  2:0]  AXI_12_ARSIZE;
  wire          AXI_12_ARVALID;
  wire [ 32:0]  AXI_12_AWADDR;
  wire [  1:0]  AXI_12_AWBURST;
  wire [  5:0]  AXI_12_AWID;
  wire [  7:0]  AXI_12_AWLEN;
  wire [  2:0]  AXI_12_AWSIZE;
  wire          AXI_12_AWVALID;
  wire          AXI_12_RREADY;
  wire          AXI_12_BREADY;
  wire [255:0]  AXI_12_WDATA;
  wire          AXI_12_WLAST;
  wire [ 31:0]  AXI_12_WSTRB;
  wire [ 31:0]  AXI_12_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_12_WDATA_PARITY;
  wire          AXI_12_WVALID;
  wire [3:0]    AXI_12_ARCACHE;
  wire [3:0]    AXI_12_AWCACHE;
  wire [2:0]    AXI_12_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_12;
`endif
  wire      [31:0]  prbs_mode_seed_12 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_13;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_13;
  wire [ 32:0]  AXI_13_ARADDR;
  wire [  1:0]  AXI_13_ARBURST;
  wire [  5:0]  AXI_13_ARID;
  wire [  7:0]  AXI_13_ARLEN;
  wire [  2:0]  AXI_13_ARSIZE;
  wire          AXI_13_ARVALID;
  wire [ 32:0]  AXI_13_AWADDR;
  wire [  1:0]  AXI_13_AWBURST;
  wire [  5:0]  AXI_13_AWID;
  wire [  7:0]  AXI_13_AWLEN;
  wire [  2:0]  AXI_13_AWSIZE;
  wire          AXI_13_AWVALID;
  wire          AXI_13_RREADY;
  wire          AXI_13_BREADY;
  wire [255:0]  AXI_13_WDATA;
  wire          AXI_13_WLAST;
  wire [ 31:0]  AXI_13_WSTRB;
  wire [ 31:0]  AXI_13_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_13_WDATA_PARITY;
  wire          AXI_13_WVALID;
  wire [3:0]    AXI_13_ARCACHE;
  wire [3:0]    AXI_13_AWCACHE;
  wire [2:0]    AXI_13_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_13;
`endif
  wire      [31:0]  prbs_mode_seed_13 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_14;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_14;
  wire [ 32:0]  AXI_14_ARADDR;
  wire [  1:0]  AXI_14_ARBURST;
  wire [  5:0]  AXI_14_ARID;
  wire [  7:0]  AXI_14_ARLEN;
  wire [  2:0]  AXI_14_ARSIZE;
  wire          AXI_14_ARVALID;
  wire [ 32:0]  AXI_14_AWADDR;
  wire [  1:0]  AXI_14_AWBURST;
  wire [  5:0]  AXI_14_AWID;
  wire [  7:0]  AXI_14_AWLEN;
  wire [  2:0]  AXI_14_AWSIZE;
  wire          AXI_14_AWVALID;
  wire          AXI_14_RREADY;
  wire          AXI_14_BREADY;
  wire [255:0]  AXI_14_WDATA;
  wire          AXI_14_WLAST;
  wire [ 31:0]  AXI_14_WSTRB;
  wire [ 31:0]  AXI_14_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_14_WDATA_PARITY;
  wire          AXI_14_WVALID;
  wire [3:0]    AXI_14_ARCACHE;
  wire [3:0]    AXI_14_AWCACHE;
  wire [2:0]    AXI_14_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_14;
`endif
  wire      [31:0]  prbs_mode_seed_14 = 32'habcd_1234;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_15;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_15;
  wire [ 32:0]  AXI_15_ARADDR;
  wire [  1:0]  AXI_15_ARBURST;
  wire [  5:0]  AXI_15_ARID;
  wire [  7:0]  AXI_15_ARLEN;
  wire [  2:0]  AXI_15_ARSIZE;
  wire          AXI_15_ARVALID;
  wire [ 32:0]  AXI_15_AWADDR;
  wire [  1:0]  AXI_15_AWBURST;
  wire [  5:0]  AXI_15_AWID;
  wire [  7:0]  AXI_15_AWLEN;
  wire [  2:0]  AXI_15_AWSIZE;
  wire          AXI_15_AWVALID;
  wire          AXI_15_RREADY;
  wire          AXI_15_BREADY;
  wire [255:0]  AXI_15_WDATA;
  wire          AXI_15_WLAST;
  wire [ 31:0]  AXI_15_WSTRB;
  wire [ 31:0]  AXI_15_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_15_WDATA_PARITY;
  wire          AXI_15_WVALID;
  wire [3:0]    AXI_15_ARCACHE;
  wire [3:0]    AXI_15_AWCACHE;
  wire [2:0]    AXI_15_AWPROT;
`ifndef SIMULATION_MODE
  wire              boot_mode_done_15;
`endif
  wire      [31:0]  prbs_mode_seed_15 = 32'habcd_1234;


  wire          AXI_00_ARREADY;
  wire          AXI_00_AWREADY;
  wire [ 31:0]  AXI_00_RDATA_PARITY;
  wire [255:0]  AXI_00_RDATA;
  wire [  5:0]  AXI_00_RID;
  wire          AXI_00_RLAST;
  wire [  1:0]  AXI_00_RRESP;
  wire          AXI_00_RVALID;
  wire          AXI_00_WREADY;
  wire [  5:0]  AXI_00_BID;
  wire [  1:0]  AXI_00_BRESP;
  wire          AXI_00_BVALID;
  wire          AXI_01_ARREADY;
  wire          AXI_01_AWREADY;
  wire [ 31:0]  AXI_01_RDATA_PARITY;
  wire [255:0]  AXI_01_RDATA;
  wire [  5:0]  AXI_01_RID;
  wire          AXI_01_RLAST;
  wire [  1:0]  AXI_01_RRESP;
  wire          AXI_01_RVALID;
  wire          AXI_01_WREADY;
  wire [  5:0]  AXI_01_BID;
  wire [  1:0]  AXI_01_BRESP;
  wire          AXI_01_BVALID;
  wire          AXI_02_ARREADY;
  wire          AXI_02_AWREADY;
  wire [ 31:0]  AXI_02_RDATA_PARITY;
  wire [255:0]  AXI_02_RDATA;
  wire [  5:0]  AXI_02_RID;
  wire          AXI_02_RLAST;
  wire [  1:0]  AXI_02_RRESP;
  wire          AXI_02_RVALID;
  wire          AXI_02_WREADY;
  wire [  5:0]  AXI_02_BID;
  wire [  1:0]  AXI_02_BRESP;
  wire          AXI_02_BVALID;
  wire          AXI_03_ARREADY;
  wire          AXI_03_AWREADY;
  wire [ 31:0]  AXI_03_RDATA_PARITY;
  wire [255:0]  AXI_03_RDATA;
  wire [  5:0]  AXI_03_RID;
  wire          AXI_03_RLAST;
  wire [  1:0]  AXI_03_RRESP;
  wire          AXI_03_RVALID;
  wire          AXI_03_WREADY;
  wire [  5:0]  AXI_03_BID;
  wire [  1:0]  AXI_03_BRESP;
  wire          AXI_03_BVALID;
  wire          AXI_04_ARREADY;
  wire          AXI_04_AWREADY;
  wire [ 31:0]  AXI_04_RDATA_PARITY;
  wire [255:0]  AXI_04_RDATA;
  wire [  5:0]  AXI_04_RID;
  wire          AXI_04_RLAST;
  wire [  1:0]  AXI_04_RRESP;
  wire          AXI_04_RVALID;
  wire          AXI_04_WREADY;
  wire [  5:0]  AXI_04_BID;
  wire [  1:0]  AXI_04_BRESP;
  wire          AXI_04_BVALID;
  wire          AXI_05_ARREADY;
  wire          AXI_05_AWREADY;
  wire [ 31:0]  AXI_05_RDATA_PARITY;
  wire [255:0]  AXI_05_RDATA;
  wire [  5:0]  AXI_05_RID;
  wire          AXI_05_RLAST;
  wire [  1:0]  AXI_05_RRESP;
  wire          AXI_05_RVALID;
  wire          AXI_05_WREADY;
  wire [  5:0]  AXI_05_BID;
  wire [  1:0]  AXI_05_BRESP;
  wire          AXI_05_BVALID;
  wire          AXI_06_ARREADY;
  wire          AXI_06_AWREADY;
  wire [ 31:0]  AXI_06_RDATA_PARITY;
  wire [255:0]  AXI_06_RDATA;
  wire [  5:0]  AXI_06_RID;
  wire          AXI_06_RLAST;
  wire [  1:0]  AXI_06_RRESP;
  wire          AXI_06_RVALID;
  wire          AXI_06_WREADY;
  wire [  5:0]  AXI_06_BID;
  wire [  1:0]  AXI_06_BRESP;
  wire          AXI_06_BVALID;
  wire          AXI_07_ARREADY;
  wire          AXI_07_AWREADY;
  wire [ 31:0]  AXI_07_RDATA_PARITY;
  wire [255:0]  AXI_07_RDATA;
  wire [  5:0]  AXI_07_RID;
  wire          AXI_07_RLAST;
  wire [  1:0]  AXI_07_RRESP;
  wire          AXI_07_RVALID;
  wire          AXI_07_WREADY;
  wire [  5:0]  AXI_07_BID;
  wire [  1:0]  AXI_07_BRESP;
  wire          AXI_07_BVALID;
  wire          AXI_08_ARREADY;
  wire          AXI_08_AWREADY;
  wire [ 31:0]  AXI_08_RDATA_PARITY;
  wire [255:0]  AXI_08_RDATA;
  wire [  5:0]  AXI_08_RID;
  wire          AXI_08_RLAST;
  wire [  1:0]  AXI_08_RRESP;
  wire          AXI_08_RVALID;
  wire          AXI_08_WREADY;
  wire [  5:0]  AXI_08_BID;
  wire [  1:0]  AXI_08_BRESP;
  wire          AXI_08_BVALID;
  wire          AXI_09_ARREADY;
  wire          AXI_09_AWREADY;
  wire [ 31:0]  AXI_09_RDATA_PARITY;
  wire [255:0]  AXI_09_RDATA;
  wire [  5:0]  AXI_09_RID;
  wire          AXI_09_RLAST;
  wire [  1:0]  AXI_09_RRESP;
  wire          AXI_09_RVALID;
  wire          AXI_09_WREADY;
  wire [  5:0]  AXI_09_BID;
  wire [  1:0]  AXI_09_BRESP;
  wire          AXI_09_BVALID;
  wire          AXI_10_ARREADY;
  wire          AXI_10_AWREADY;
  wire [ 31:0]  AXI_10_RDATA_PARITY;
  wire [255:0]  AXI_10_RDATA;
  wire [  5:0]  AXI_10_RID;
  wire          AXI_10_RLAST;
  wire [  1:0]  AXI_10_RRESP;
  wire          AXI_10_RVALID;
  wire          AXI_10_WREADY;
  wire [  5:0]  AXI_10_BID;
  wire [  1:0]  AXI_10_BRESP;
  wire          AXI_10_BVALID;
  wire          AXI_11_ARREADY;
  wire          AXI_11_AWREADY;
  wire [ 31:0]  AXI_11_RDATA_PARITY;
  wire [255:0]  AXI_11_RDATA;
  wire [  5:0]  AXI_11_RID;
  wire          AXI_11_RLAST;
  wire [  1:0]  AXI_11_RRESP;
  wire          AXI_11_RVALID;
  wire          AXI_11_WREADY;
  wire [  5:0]  AXI_11_BID;
  wire [  1:0]  AXI_11_BRESP;
  wire          AXI_11_BVALID;
  wire          AXI_12_ARREADY;
  wire          AXI_12_AWREADY;
  wire [ 31:0]  AXI_12_RDATA_PARITY;
  wire [255:0]  AXI_12_RDATA;
  wire [  5:0]  AXI_12_RID;
  wire          AXI_12_RLAST;
  wire [  1:0]  AXI_12_RRESP;
  wire          AXI_12_RVALID;
  wire          AXI_12_WREADY;
  wire [  5:0]  AXI_12_BID;
  wire [  1:0]  AXI_12_BRESP;
  wire          AXI_12_BVALID;
  wire          AXI_13_ARREADY;
  wire          AXI_13_AWREADY;
  wire [ 31:0]  AXI_13_RDATA_PARITY;
  wire [255:0]  AXI_13_RDATA;
  wire [  5:0]  AXI_13_RID;
  wire          AXI_13_RLAST;
  wire [  1:0]  AXI_13_RRESP;
  wire          AXI_13_RVALID;
  wire          AXI_13_WREADY;
  wire [  5:0]  AXI_13_BID;
  wire [  1:0]  AXI_13_BRESP;
  wire          AXI_13_BVALID;
  wire          AXI_14_ARREADY;
  wire          AXI_14_AWREADY;
  wire [ 31:0]  AXI_14_RDATA_PARITY;
  wire [255:0]  AXI_14_RDATA;
  wire [  5:0]  AXI_14_RID;
  wire          AXI_14_RLAST;
  wire [  1:0]  AXI_14_RRESP;
  wire          AXI_14_RVALID;
  wire          AXI_14_WREADY;
  wire [  5:0]  AXI_14_BID;
  wire [  1:0]  AXI_14_BRESP;
  wire          AXI_14_BVALID;
  wire          AXI_15_ARREADY;
  wire          AXI_15_AWREADY;
  wire [ 31:0]  AXI_15_RDATA_PARITY;
  wire [255:0]  AXI_15_RDATA;
  wire [  5:0]  AXI_15_RID;
  wire          AXI_15_RLAST;
  wire [  1:0]  AXI_15_RRESP;
  wire          AXI_15_RVALID;
  wire          AXI_15_WREADY;
  wire [  5:0]  AXI_15_BID;
  wire [  1:0]  AXI_15_BRESP;
  wire          AXI_15_BVALID;

  wire          DRAM_0_STAT_CATTRIP;
  wire [  6:0]  DRAM_0_STAT_TEMP;


`ifndef SIMULATION_MODE
  wire          axi_00_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_01_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_02_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_03_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_04_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_05_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_06_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_07_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_08_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_09_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_10_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_11_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_12_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_13_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_14_data_msmatch_err;
`endif
`ifndef SIMULATION_MODE
  wire          axi_15_data_msmatch_err;
`endif
  wire          axi_16_data_msmatch_err = 1'b0;
  wire          axi_17_data_msmatch_err = 1'b0;
  wire          axi_18_data_msmatch_err = 1'b0;
  wire          axi_19_data_msmatch_err = 1'b0;
  wire          axi_20_data_msmatch_err = 1'b0;
  wire          axi_21_data_msmatch_err = 1'b0;
  wire          axi_22_data_msmatch_err = 1'b0;
  wire          axi_23_data_msmatch_err = 1'b0;
  wire          axi_24_data_msmatch_err = 1'b0;
  wire          axi_25_data_msmatch_err = 1'b0;
  wire          axi_26_data_msmatch_err = 1'b0;
  wire          axi_27_data_msmatch_err = 1'b0;
  wire          axi_28_data_msmatch_err = 1'b0;
  wire          axi_29_data_msmatch_err = 1'b0;
  wire          axi_30_data_msmatch_err = 1'b0;
  wire          axi_31_data_msmatch_err = 1'b0;
  wire                        vio_tg_rst_0;
  wire                        vio_tg_start_0;
  wire                        vio_tg_err_chk_en_0;
  wire                        vio_tg_err_clear_0;
  wire [3:0]                  vio_tg_instr_addr_mode_0;
  wire [3:0]                  vio_tg_instr_data_mode_0;
  wire [3:0]                  vio_tg_instr_rw_mode_0;
  wire [1:0]                  vio_tg_instr_rw_submode_0;
  wire [31:0]                 vio_tg_instr_num_of_iter_0;
  wire [5:0]                  vio_tg_instr_nxt_instr_0;
  wire                        vio_tg_restart_0;
  wire                        vio_tg_pause_0;
  wire                        vio_tg_err_clear_all_0;
  wire                        vio_tg_err_continue_0;
  wire                        vio_tg_instr_program_en_0;
  wire                        vio_tg_direct_instr_en_0;
  wire [4:0]                  vio_tg_instr_num_0;
  wire [2:0]                  vio_tg_instr_victim_mode_0;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_0;
  wire [2:0]                  vio_tg_instr_victim_select_0;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_0;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_0;
  wire                        vio_tg_seed_program_en_0;
  wire [7:0]                  vio_tg_seed_num_0;
  wire [22:0]                 vio_tg_seed_0;
  wire [7:0]                  vio_tg_glb_victim_bit_0;
  wire [32:0]                 vio_tg_glb_start_addr_0;
  wire [3:0]                  vio_tg_status_state_0;
  wire                        vio_tg_status_err_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_0;
  wire [31:0]                 vio_tg_status_err_cnt_0;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_0;
  wire                        vio_tg_status_exp_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_0;
  wire                        vio_tg_status_read_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_0;
  wire                        vio_tg_status_first_err_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_0;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_0;
  wire                        vio_tg_status_first_exp_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_0;
  wire                        vio_tg_status_first_read_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_0;
  wire                        vio_tg_status_err_bit_sticky_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_0;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_0;
  wire                        vio_tg_status_err_type_valid_0;
  wire                        vio_tg_status_err_type_0;
  wire                        vio_tg_status_wr_done_0;
  wire                        vio_tg_status_watch_dog_hang_0;
  wire                        tg_ila_debug_0;
  reg  [4:0]                  wr_cnt_00;
  reg  [4:0]                  rd_cnt_00;

  wire                        vio_tg_rst_1;
  wire                        vio_tg_start_1;
  wire                        vio_tg_err_chk_en_1;
  wire                        vio_tg_err_clear_1;
  wire [3:0]                  vio_tg_instr_addr_mode_1;
  wire [3:0]                  vio_tg_instr_data_mode_1;
  wire [3:0]                  vio_tg_instr_rw_mode_1;
  wire [1:0]                  vio_tg_instr_rw_submode_1;
  wire [31:0]                 vio_tg_instr_num_of_iter_1;
  wire [5:0]                  vio_tg_instr_nxt_instr_1;
  wire                        vio_tg_restart_1;
  wire                        vio_tg_pause_1;
  wire                        vio_tg_err_clear_all_1;
  wire                        vio_tg_err_continue_1;
  wire                        vio_tg_instr_program_en_1;
  wire                        vio_tg_direct_instr_en_1;
  wire [4:0]                  vio_tg_instr_num_1;
  wire [2:0]                  vio_tg_instr_victim_mode_1;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_1;
  wire [2:0]                  vio_tg_instr_victim_select_1;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_1;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_1;
  wire                        vio_tg_seed_program_en_1;
  wire [7:0]                  vio_tg_seed_num_1;
  wire [22:0]                 vio_tg_seed_1;
  wire [7:0]                  vio_tg_glb_victim_bit_1;
  wire [32:0]                 vio_tg_glb_start_addr_1;
  wire [3:0]                  vio_tg_status_state_1;
  wire                        vio_tg_status_err_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_1;
  wire [31:0]                 vio_tg_status_err_cnt_1;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_1;
  wire                        vio_tg_status_exp_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_1;
  wire                        vio_tg_status_read_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_1;
  wire                        vio_tg_status_first_err_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_1;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_1;
  wire                        vio_tg_status_first_exp_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_1;
  wire                        vio_tg_status_first_read_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_1;
  wire                        vio_tg_status_err_bit_sticky_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_1;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_1;
  wire                        vio_tg_status_err_type_valid_1;
  wire                        vio_tg_status_err_type_1;
  wire                        vio_tg_status_wr_done_1;
  wire                        vio_tg_status_watch_dog_hang_1;
  wire                        tg_ila_debug_1;
  reg  [4:0]                  wr_cnt_01;
  reg  [4:0]                  rd_cnt_01;

  wire                        vio_tg_rst_2;
  wire                        vio_tg_start_2;
  wire                        vio_tg_err_chk_en_2;
  wire                        vio_tg_err_clear_2;
  wire [3:0]                  vio_tg_instr_addr_mode_2;
  wire [3:0]                  vio_tg_instr_data_mode_2;
  wire [3:0]                  vio_tg_instr_rw_mode_2;
  wire [1:0]                  vio_tg_instr_rw_submode_2;
  wire [31:0]                 vio_tg_instr_num_of_iter_2;
  wire [5:0]                  vio_tg_instr_nxt_instr_2;
  wire                        vio_tg_restart_2;
  wire                        vio_tg_pause_2;
  wire                        vio_tg_err_clear_all_2;
  wire                        vio_tg_err_continue_2;
  wire                        vio_tg_instr_program_en_2;
  wire                        vio_tg_direct_instr_en_2;
  wire [4:0]                  vio_tg_instr_num_2;
  wire [2:0]                  vio_tg_instr_victim_mode_2;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_2;
  wire [2:0]                  vio_tg_instr_victim_select_2;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_2;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_2;
  wire                        vio_tg_seed_program_en_2;
  wire [7:0]                  vio_tg_seed_num_2;
  wire [22:0]                 vio_tg_seed_2;
  wire [7:0]                  vio_tg_glb_victim_bit_2;
  wire [32:0]                 vio_tg_glb_start_addr_2;
  wire [3:0]                  vio_tg_status_state_2;
  wire                        vio_tg_status_err_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_2;
  wire [31:0]                 vio_tg_status_err_cnt_2;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_2;
  wire                        vio_tg_status_exp_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_2;
  wire                        vio_tg_status_read_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_2;
  wire                        vio_tg_status_first_err_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_2;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_2;
  wire                        vio_tg_status_first_exp_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_2;
  wire                        vio_tg_status_first_read_bit_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_2;
  wire                        vio_tg_status_err_bit_sticky_valid_2;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_2;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_2;
  wire                        vio_tg_status_err_type_valid_2;
  wire                        vio_tg_status_err_type_2;
  wire                        vio_tg_status_wr_done_2;
  wire                        vio_tg_status_watch_dog_hang_2;
  wire                        tg_ila_debug_2;
  reg  [4:0]                  wr_cnt_02;
  reg  [4:0]                  rd_cnt_02;

  wire                        vio_tg_rst_3;
  wire                        vio_tg_start_3;
  wire                        vio_tg_err_chk_en_3;
  wire                        vio_tg_err_clear_3;
  wire [3:0]                  vio_tg_instr_addr_mode_3;
  wire [3:0]                  vio_tg_instr_data_mode_3;
  wire [3:0]                  vio_tg_instr_rw_mode_3;
  wire [1:0]                  vio_tg_instr_rw_submode_3;
  wire [31:0]                 vio_tg_instr_num_of_iter_3;
  wire [5:0]                  vio_tg_instr_nxt_instr_3;
  wire                        vio_tg_restart_3;
  wire                        vio_tg_pause_3;
  wire                        vio_tg_err_clear_all_3;
  wire                        vio_tg_err_continue_3;
  wire                        vio_tg_instr_program_en_3;
  wire                        vio_tg_direct_instr_en_3;
  wire [4:0]                  vio_tg_instr_num_3;
  wire [2:0]                  vio_tg_instr_victim_mode_3;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_3;
  wire [2:0]                  vio_tg_instr_victim_select_3;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_3;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_3;
  wire                        vio_tg_seed_program_en_3;
  wire [7:0]                  vio_tg_seed_num_3;
  wire [22:0]                 vio_tg_seed_3;
  wire [7:0]                  vio_tg_glb_victim_bit_3;
  wire [32:0]                 vio_tg_glb_start_addr_3;
  wire [3:0]                  vio_tg_status_state_3;
  wire                        vio_tg_status_err_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_3;
  wire [31:0]                 vio_tg_status_err_cnt_3;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_3;
  wire                        vio_tg_status_exp_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_3;
  wire                        vio_tg_status_read_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_3;
  wire                        vio_tg_status_first_err_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_3;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_3;
  wire                        vio_tg_status_first_exp_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_3;
  wire                        vio_tg_status_first_read_bit_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_3;
  wire                        vio_tg_status_err_bit_sticky_valid_3;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_3;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_3;
  wire                        vio_tg_status_err_type_valid_3;
  wire                        vio_tg_status_err_type_3;
  wire                        vio_tg_status_wr_done_3;
  wire                        vio_tg_status_watch_dog_hang_3;
  wire                        tg_ila_debug_3;
  reg  [4:0]                  wr_cnt_03;
  reg  [4:0]                  rd_cnt_03;

  wire                        vio_tg_rst_4;
  wire                        vio_tg_start_4;
  wire                        vio_tg_err_chk_en_4;
  wire                        vio_tg_err_clear_4;
  wire [3:0]                  vio_tg_instr_addr_mode_4;
  wire [3:0]                  vio_tg_instr_data_mode_4;
  wire [3:0]                  vio_tg_instr_rw_mode_4;
  wire [1:0]                  vio_tg_instr_rw_submode_4;
  wire [31:0]                 vio_tg_instr_num_of_iter_4;
  wire [5:0]                  vio_tg_instr_nxt_instr_4;
  wire                        vio_tg_restart_4;
  wire                        vio_tg_pause_4;
  wire                        vio_tg_err_clear_all_4;
  wire                        vio_tg_err_continue_4;
  wire                        vio_tg_instr_program_en_4;
  wire                        vio_tg_direct_instr_en_4;
  wire [4:0]                  vio_tg_instr_num_4;
  wire [2:0]                  vio_tg_instr_victim_mode_4;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_4;
  wire [2:0]                  vio_tg_instr_victim_select_4;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_4;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_4;
  wire                        vio_tg_seed_program_en_4;
  wire [7:0]                  vio_tg_seed_num_4;
  wire [22:0]                 vio_tg_seed_4;
  wire [7:0]                  vio_tg_glb_victim_bit_4;
  wire [32:0]                 vio_tg_glb_start_addr_4;
  wire [3:0]                  vio_tg_status_state_4;
  wire                        vio_tg_status_err_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_4;
  wire [31:0]                 vio_tg_status_err_cnt_4;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_4;
  wire                        vio_tg_status_exp_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_4;
  wire                        vio_tg_status_read_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_4;
  wire                        vio_tg_status_first_err_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_4;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_4;
  wire                        vio_tg_status_first_exp_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_4;
  wire                        vio_tg_status_first_read_bit_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_4;
  wire                        vio_tg_status_err_bit_sticky_valid_4;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_4;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_4;
  wire                        vio_tg_status_err_type_valid_4;
  wire                        vio_tg_status_err_type_4;
  wire                        vio_tg_status_wr_done_4;
  wire                        vio_tg_status_watch_dog_hang_4;
  wire                        tg_ila_debug_4;
  reg  [4:0]                  wr_cnt_04;
  reg  [4:0]                  rd_cnt_04;

  wire                        vio_tg_rst_5;
  wire                        vio_tg_start_5;
  wire                        vio_tg_err_chk_en_5;
  wire                        vio_tg_err_clear_5;
  wire [3:0]                  vio_tg_instr_addr_mode_5;
  wire [3:0]                  vio_tg_instr_data_mode_5;
  wire [3:0]                  vio_tg_instr_rw_mode_5;
  wire [1:0]                  vio_tg_instr_rw_submode_5;
  wire [31:0]                 vio_tg_instr_num_of_iter_5;
  wire [5:0]                  vio_tg_instr_nxt_instr_5;
  wire                        vio_tg_restart_5;
  wire                        vio_tg_pause_5;
  wire                        vio_tg_err_clear_all_5;
  wire                        vio_tg_err_continue_5;
  wire                        vio_tg_instr_program_en_5;
  wire                        vio_tg_direct_instr_en_5;
  wire [4:0]                  vio_tg_instr_num_5;
  wire [2:0]                  vio_tg_instr_victim_mode_5;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_5;
  wire [2:0]                  vio_tg_instr_victim_select_5;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_5;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_5;
  wire                        vio_tg_seed_program_en_5;
  wire [7:0]                  vio_tg_seed_num_5;
  wire [22:0]                 vio_tg_seed_5;
  wire [7:0]                  vio_tg_glb_victim_bit_5;
  wire [32:0]                 vio_tg_glb_start_addr_5;
  wire [3:0]                  vio_tg_status_state_5;
  wire                        vio_tg_status_err_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_5;
  wire [31:0]                 vio_tg_status_err_cnt_5;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_5;
  wire                        vio_tg_status_exp_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_5;
  wire                        vio_tg_status_read_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_5;
  wire                        vio_tg_status_first_err_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_5;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_5;
  wire                        vio_tg_status_first_exp_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_5;
  wire                        vio_tg_status_first_read_bit_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_5;
  wire                        vio_tg_status_err_bit_sticky_valid_5;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_5;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_5;
  wire                        vio_tg_status_err_type_valid_5;
  wire                        vio_tg_status_err_type_5;
  wire                        vio_tg_status_wr_done_5;
  wire                        vio_tg_status_watch_dog_hang_5;
  wire                        tg_ila_debug_5;
  reg  [4:0]                  wr_cnt_05;
  reg  [4:0]                  rd_cnt_05;

  wire                        vio_tg_rst_6;
  wire                        vio_tg_start_6;
  wire                        vio_tg_err_chk_en_6;
  wire                        vio_tg_err_clear_6;
  wire [3:0]                  vio_tg_instr_addr_mode_6;
  wire [3:0]                  vio_tg_instr_data_mode_6;
  wire [3:0]                  vio_tg_instr_rw_mode_6;
  wire [1:0]                  vio_tg_instr_rw_submode_6;
  wire [31:0]                 vio_tg_instr_num_of_iter_6;
  wire [5:0]                  vio_tg_instr_nxt_instr_6;
  wire                        vio_tg_restart_6;
  wire                        vio_tg_pause_6;
  wire                        vio_tg_err_clear_all_6;
  wire                        vio_tg_err_continue_6;
  wire                        vio_tg_instr_program_en_6;
  wire                        vio_tg_direct_instr_en_6;
  wire [4:0]                  vio_tg_instr_num_6;
  wire [2:0]                  vio_tg_instr_victim_mode_6;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_6;
  wire [2:0]                  vio_tg_instr_victim_select_6;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_6;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_6;
  wire                        vio_tg_seed_program_en_6;
  wire [7:0]                  vio_tg_seed_num_6;
  wire [22:0]                 vio_tg_seed_6;
  wire [7:0]                  vio_tg_glb_victim_bit_6;
  wire [32:0]                 vio_tg_glb_start_addr_6;
  wire [3:0]                  vio_tg_status_state_6;
  wire                        vio_tg_status_err_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_6;
  wire [31:0]                 vio_tg_status_err_cnt_6;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_6;
  wire                        vio_tg_status_exp_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_6;
  wire                        vio_tg_status_read_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_6;
  wire                        vio_tg_status_first_err_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_6;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_6;
  wire                        vio_tg_status_first_exp_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_6;
  wire                        vio_tg_status_first_read_bit_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_6;
  wire                        vio_tg_status_err_bit_sticky_valid_6;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_6;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_6;
  wire                        vio_tg_status_err_type_valid_6;
  wire                        vio_tg_status_err_type_6;
  wire                        vio_tg_status_wr_done_6;
  wire                        vio_tg_status_watch_dog_hang_6;
  wire                        tg_ila_debug_6;
  reg  [4:0]                  wr_cnt_06;
  reg  [4:0]                  rd_cnt_06;

  wire                        vio_tg_rst_7;
  wire                        vio_tg_start_7;
  wire                        vio_tg_err_chk_en_7;
  wire                        vio_tg_err_clear_7;
  wire [3:0]                  vio_tg_instr_addr_mode_7;
  wire [3:0]                  vio_tg_instr_data_mode_7;
  wire [3:0]                  vio_tg_instr_rw_mode_7;
  wire [1:0]                  vio_tg_instr_rw_submode_7;
  wire [31:0]                 vio_tg_instr_num_of_iter_7;
  wire [5:0]                  vio_tg_instr_nxt_instr_7;
  wire                        vio_tg_restart_7;
  wire                        vio_tg_pause_7;
  wire                        vio_tg_err_clear_all_7;
  wire                        vio_tg_err_continue_7;
  wire                        vio_tg_instr_program_en_7;
  wire                        vio_tg_direct_instr_en_7;
  wire [4:0]                  vio_tg_instr_num_7;
  wire [2:0]                  vio_tg_instr_victim_mode_7;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_7;
  wire [2:0]                  vio_tg_instr_victim_select_7;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_7;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_7;
  wire                        vio_tg_seed_program_en_7;
  wire [7:0]                  vio_tg_seed_num_7;
  wire [22:0]                 vio_tg_seed_7;
  wire [7:0]                  vio_tg_glb_victim_bit_7;
  wire [32:0]                 vio_tg_glb_start_addr_7;
  wire [3:0]                  vio_tg_status_state_7;
  wire                        vio_tg_status_err_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_7;
  wire [31:0]                 vio_tg_status_err_cnt_7;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_7;
  wire                        vio_tg_status_exp_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_7;
  wire                        vio_tg_status_read_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_7;
  wire                        vio_tg_status_first_err_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_7;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_7;
  wire                        vio_tg_status_first_exp_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_7;
  wire                        vio_tg_status_first_read_bit_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_7;
  wire                        vio_tg_status_err_bit_sticky_valid_7;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_7;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_7;
  wire                        vio_tg_status_err_type_valid_7;
  wire                        vio_tg_status_err_type_7;
  wire                        vio_tg_status_wr_done_7;
  wire                        vio_tg_status_watch_dog_hang_7;
  wire                        tg_ila_debug_7;
  reg  [4:0]                  wr_cnt_07;
  reg  [4:0]                  rd_cnt_07;

  wire                        vio_tg_rst_8;
  wire                        vio_tg_start_8;
  wire                        vio_tg_err_chk_en_8;
  wire                        vio_tg_err_clear_8;
  wire [3:0]                  vio_tg_instr_addr_mode_8;
  wire [3:0]                  vio_tg_instr_data_mode_8;
  wire [3:0]                  vio_tg_instr_rw_mode_8;
  wire [1:0]                  vio_tg_instr_rw_submode_8;
  wire [31:0]                 vio_tg_instr_num_of_iter_8;
  wire [5:0]                  vio_tg_instr_nxt_instr_8;
  wire                        vio_tg_restart_8;
  wire                        vio_tg_pause_8;
  wire                        vio_tg_err_clear_all_8;
  wire                        vio_tg_err_continue_8;
  wire                        vio_tg_instr_program_en_8;
  wire                        vio_tg_direct_instr_en_8;
  wire [4:0]                  vio_tg_instr_num_8;
  wire [2:0]                  vio_tg_instr_victim_mode_8;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_8;
  wire [2:0]                  vio_tg_instr_victim_select_8;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_8;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_8;
  wire                        vio_tg_seed_program_en_8;
  wire [7:0]                  vio_tg_seed_num_8;
  wire [22:0]                 vio_tg_seed_8;
  wire [7:0]                  vio_tg_glb_victim_bit_8;
  wire [32:0]                 vio_tg_glb_start_addr_8;
  wire [3:0]                  vio_tg_status_state_8;
  wire                        vio_tg_status_err_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_8;
  wire [31:0]                 vio_tg_status_err_cnt_8;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_8;
  wire                        vio_tg_status_exp_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_8;
  wire                        vio_tg_status_read_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_8;
  wire                        vio_tg_status_first_err_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_8;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_8;
  wire                        vio_tg_status_first_exp_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_8;
  wire                        vio_tg_status_first_read_bit_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_8;
  wire                        vio_tg_status_err_bit_sticky_valid_8;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_8;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_8;
  wire                        vio_tg_status_err_type_valid_8;
  wire                        vio_tg_status_err_type_8;
  wire                        vio_tg_status_wr_done_8;
  wire                        vio_tg_status_watch_dog_hang_8;
  wire                        tg_ila_debug_8;
  reg  [4:0]                  wr_cnt_08;
  reg  [4:0]                  rd_cnt_08;

  wire                        vio_tg_rst_9;
  wire                        vio_tg_start_9;
  wire                        vio_tg_err_chk_en_9;
  wire                        vio_tg_err_clear_9;
  wire [3:0]                  vio_tg_instr_addr_mode_9;
  wire [3:0]                  vio_tg_instr_data_mode_9;
  wire [3:0]                  vio_tg_instr_rw_mode_9;
  wire [1:0]                  vio_tg_instr_rw_submode_9;
  wire [31:0]                 vio_tg_instr_num_of_iter_9;
  wire [5:0]                  vio_tg_instr_nxt_instr_9;
  wire                        vio_tg_restart_9;
  wire                        vio_tg_pause_9;
  wire                        vio_tg_err_clear_all_9;
  wire                        vio_tg_err_continue_9;
  wire                        vio_tg_instr_program_en_9;
  wire                        vio_tg_direct_instr_en_9;
  wire [4:0]                  vio_tg_instr_num_9;
  wire [2:0]                  vio_tg_instr_victim_mode_9;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_9;
  wire [2:0]                  vio_tg_instr_victim_select_9;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_9;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_9;
  wire                        vio_tg_seed_program_en_9;
  wire [7:0]                  vio_tg_seed_num_9;
  wire [22:0]                 vio_tg_seed_9;
  wire [7:0]                  vio_tg_glb_victim_bit_9;
  wire [32:0]                 vio_tg_glb_start_addr_9;
  wire [3:0]                  vio_tg_status_state_9;
  wire                        vio_tg_status_err_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_9;
  wire [31:0]                 vio_tg_status_err_cnt_9;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_9;
  wire                        vio_tg_status_exp_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_9;
  wire                        vio_tg_status_read_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_9;
  wire                        vio_tg_status_first_err_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_9;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_9;
  wire                        vio_tg_status_first_exp_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_9;
  wire                        vio_tg_status_first_read_bit_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_9;
  wire                        vio_tg_status_err_bit_sticky_valid_9;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_9;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_9;
  wire                        vio_tg_status_err_type_valid_9;
  wire                        vio_tg_status_err_type_9;
  wire                        vio_tg_status_wr_done_9;
  wire                        vio_tg_status_watch_dog_hang_9;
  wire                        tg_ila_debug_9;
  reg  [4:0]                  wr_cnt_09;
  reg  [4:0]                  rd_cnt_09;

  wire                        vio_tg_rst_10;
  wire                        vio_tg_start_10;
  wire                        vio_tg_err_chk_en_10;
  wire                        vio_tg_err_clear_10;
  wire [3:0]                  vio_tg_instr_addr_mode_10;
  wire [3:0]                  vio_tg_instr_data_mode_10;
  wire [3:0]                  vio_tg_instr_rw_mode_10;
  wire [1:0]                  vio_tg_instr_rw_submode_10;
  wire [31:0]                 vio_tg_instr_num_of_iter_10;
  wire [5:0]                  vio_tg_instr_nxt_instr_10;
  wire                        vio_tg_restart_10;
  wire                        vio_tg_pause_10;
  wire                        vio_tg_err_clear_all_10;
  wire                        vio_tg_err_continue_10;
  wire                        vio_tg_instr_program_en_10;
  wire                        vio_tg_direct_instr_en_10;
  wire [4:0]                  vio_tg_instr_num_10;
  wire [2:0]                  vio_tg_instr_victim_mode_10;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_10;
  wire [2:0]                  vio_tg_instr_victim_select_10;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_10;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_10;
  wire                        vio_tg_seed_program_en_10;
  wire [7:0]                  vio_tg_seed_num_10;
  wire [22:0]                 vio_tg_seed_10;
  wire [7:0]                  vio_tg_glb_victim_bit_10;
  wire [32:0]                 vio_tg_glb_start_addr_10;
  wire [3:0]                  vio_tg_status_state_10;
  wire                        vio_tg_status_err_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_10;
  wire [31:0]                 vio_tg_status_err_cnt_10;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_10;
  wire                        vio_tg_status_exp_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_10;
  wire                        vio_tg_status_read_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_10;
  wire                        vio_tg_status_first_err_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_10;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_10;
  wire                        vio_tg_status_first_exp_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_10;
  wire                        vio_tg_status_first_read_bit_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_10;
  wire                        vio_tg_status_err_bit_sticky_valid_10;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_10;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_10;
  wire                        vio_tg_status_err_type_valid_10;
  wire                        vio_tg_status_err_type_10;
  wire                        vio_tg_status_wr_done_10;
  wire                        vio_tg_status_watch_dog_hang_10;
  wire                        tg_ila_debug_10;
  reg  [4:0]                  wr_cnt_10;
  reg  [4:0]                  rd_cnt_10;

  wire                        vio_tg_rst_11;
  wire                        vio_tg_start_11;
  wire                        vio_tg_err_chk_en_11;
  wire                        vio_tg_err_clear_11;
  wire [3:0]                  vio_tg_instr_addr_mode_11;
  wire [3:0]                  vio_tg_instr_data_mode_11;
  wire [3:0]                  vio_tg_instr_rw_mode_11;
  wire [1:0]                  vio_tg_instr_rw_submode_11;
  wire [31:0]                 vio_tg_instr_num_of_iter_11;
  wire [5:0]                  vio_tg_instr_nxt_instr_11;
  wire                        vio_tg_restart_11;
  wire                        vio_tg_pause_11;
  wire                        vio_tg_err_clear_all_11;
  wire                        vio_tg_err_continue_11;
  wire                        vio_tg_instr_program_en_11;
  wire                        vio_tg_direct_instr_en_11;
  wire [4:0]                  vio_tg_instr_num_11;
  wire [2:0]                  vio_tg_instr_victim_mode_11;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_11;
  wire [2:0]                  vio_tg_instr_victim_select_11;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_11;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_11;
  wire                        vio_tg_seed_program_en_11;
  wire [7:0]                  vio_tg_seed_num_11;
  wire [22:0]                 vio_tg_seed_11;
  wire [7:0]                  vio_tg_glb_victim_bit_11;
  wire [32:0]                 vio_tg_glb_start_addr_11;
  wire [3:0]                  vio_tg_status_state_11;
  wire                        vio_tg_status_err_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_11;
  wire [31:0]                 vio_tg_status_err_cnt_11;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_11;
  wire                        vio_tg_status_exp_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_11;
  wire                        vio_tg_status_read_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_11;
  wire                        vio_tg_status_first_err_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_11;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_11;
  wire                        vio_tg_status_first_exp_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_11;
  wire                        vio_tg_status_first_read_bit_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_11;
  wire                        vio_tg_status_err_bit_sticky_valid_11;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_11;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_11;
  wire                        vio_tg_status_err_type_valid_11;
  wire                        vio_tg_status_err_type_11;
  wire                        vio_tg_status_wr_done_11;
  wire                        vio_tg_status_watch_dog_hang_11;
  wire                        tg_ila_debug_11;
  reg  [4:0]                  wr_cnt_11;
  reg  [4:0]                  rd_cnt_11;

  wire                        vio_tg_rst_12;
  wire                        vio_tg_start_12;
  wire                        vio_tg_err_chk_en_12;
  wire                        vio_tg_err_clear_12;
  wire [3:0]                  vio_tg_instr_addr_mode_12;
  wire [3:0]                  vio_tg_instr_data_mode_12;
  wire [3:0]                  vio_tg_instr_rw_mode_12;
  wire [1:0]                  vio_tg_instr_rw_submode_12;
  wire [31:0]                 vio_tg_instr_num_of_iter_12;
  wire [5:0]                  vio_tg_instr_nxt_instr_12;
  wire                        vio_tg_restart_12;
  wire                        vio_tg_pause_12;
  wire                        vio_tg_err_clear_all_12;
  wire                        vio_tg_err_continue_12;
  wire                        vio_tg_instr_program_en_12;
  wire                        vio_tg_direct_instr_en_12;
  wire [4:0]                  vio_tg_instr_num_12;
  wire [2:0]                  vio_tg_instr_victim_mode_12;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_12;
  wire [2:0]                  vio_tg_instr_victim_select_12;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_12;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_12;
  wire                        vio_tg_seed_program_en_12;
  wire [7:0]                  vio_tg_seed_num_12;
  wire [22:0]                 vio_tg_seed_12;
  wire [7:0]                  vio_tg_glb_victim_bit_12;
  wire [32:0]                 vio_tg_glb_start_addr_12;
  wire [3:0]                  vio_tg_status_state_12;
  wire                        vio_tg_status_err_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_12;
  wire [31:0]                 vio_tg_status_err_cnt_12;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_12;
  wire                        vio_tg_status_exp_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_12;
  wire                        vio_tg_status_read_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_12;
  wire                        vio_tg_status_first_err_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_12;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_12;
  wire                        vio_tg_status_first_exp_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_12;
  wire                        vio_tg_status_first_read_bit_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_12;
  wire                        vio_tg_status_err_bit_sticky_valid_12;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_12;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_12;
  wire                        vio_tg_status_err_type_valid_12;
  wire                        vio_tg_status_err_type_12;
  wire                        vio_tg_status_wr_done_12;
  wire                        vio_tg_status_watch_dog_hang_12;
  wire                        tg_ila_debug_12;
  reg  [4:0]                  wr_cnt_12;
  reg  [4:0]                  rd_cnt_12;

  wire                        vio_tg_rst_13;
  wire                        vio_tg_start_13;
  wire                        vio_tg_err_chk_en_13;
  wire                        vio_tg_err_clear_13;
  wire [3:0]                  vio_tg_instr_addr_mode_13;
  wire [3:0]                  vio_tg_instr_data_mode_13;
  wire [3:0]                  vio_tg_instr_rw_mode_13;
  wire [1:0]                  vio_tg_instr_rw_submode_13;
  wire [31:0]                 vio_tg_instr_num_of_iter_13;
  wire [5:0]                  vio_tg_instr_nxt_instr_13;
  wire                        vio_tg_restart_13;
  wire                        vio_tg_pause_13;
  wire                        vio_tg_err_clear_all_13;
  wire                        vio_tg_err_continue_13;
  wire                        vio_tg_instr_program_en_13;
  wire                        vio_tg_direct_instr_en_13;
  wire [4:0]                  vio_tg_instr_num_13;
  wire [2:0]                  vio_tg_instr_victim_mode_13;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_13;
  wire [2:0]                  vio_tg_instr_victim_select_13;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_13;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_13;
  wire                        vio_tg_seed_program_en_13;
  wire [7:0]                  vio_tg_seed_num_13;
  wire [22:0]                 vio_tg_seed_13;
  wire [7:0]                  vio_tg_glb_victim_bit_13;
  wire [32:0]                 vio_tg_glb_start_addr_13;
  wire [3:0]                  vio_tg_status_state_13;
  wire                        vio_tg_status_err_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_13;
  wire [31:0]                 vio_tg_status_err_cnt_13;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_13;
  wire                        vio_tg_status_exp_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_13;
  wire                        vio_tg_status_read_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_13;
  wire                        vio_tg_status_first_err_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_13;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_13;
  wire                        vio_tg_status_first_exp_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_13;
  wire                        vio_tg_status_first_read_bit_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_13;
  wire                        vio_tg_status_err_bit_sticky_valid_13;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_13;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_13;
  wire                        vio_tg_status_err_type_valid_13;
  wire                        vio_tg_status_err_type_13;
  wire                        vio_tg_status_wr_done_13;
  wire                        vio_tg_status_watch_dog_hang_13;
  wire                        tg_ila_debug_13;
  reg  [4:0]                  wr_cnt_13;
  reg  [4:0]                  rd_cnt_13;

  wire                        vio_tg_rst_14;
  wire                        vio_tg_start_14;
  wire                        vio_tg_err_chk_en_14;
  wire                        vio_tg_err_clear_14;
  wire [3:0]                  vio_tg_instr_addr_mode_14;
  wire [3:0]                  vio_tg_instr_data_mode_14;
  wire [3:0]                  vio_tg_instr_rw_mode_14;
  wire [1:0]                  vio_tg_instr_rw_submode_14;
  wire [31:0]                 vio_tg_instr_num_of_iter_14;
  wire [5:0]                  vio_tg_instr_nxt_instr_14;
  wire                        vio_tg_restart_14;
  wire                        vio_tg_pause_14;
  wire                        vio_tg_err_clear_all_14;
  wire                        vio_tg_err_continue_14;
  wire                        vio_tg_instr_program_en_14;
  wire                        vio_tg_direct_instr_en_14;
  wire [4:0]                  vio_tg_instr_num_14;
  wire [2:0]                  vio_tg_instr_victim_mode_14;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_14;
  wire [2:0]                  vio_tg_instr_victim_select_14;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_14;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_14;
  wire                        vio_tg_seed_program_en_14;
  wire [7:0]                  vio_tg_seed_num_14;
  wire [22:0]                 vio_tg_seed_14;
  wire [7:0]                  vio_tg_glb_victim_bit_14;
  wire [32:0]                 vio_tg_glb_start_addr_14;
  wire [3:0]                  vio_tg_status_state_14;
  wire                        vio_tg_status_err_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_14;
  wire [31:0]                 vio_tg_status_err_cnt_14;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_14;
  wire                        vio_tg_status_exp_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_14;
  wire                        vio_tg_status_read_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_14;
  wire                        vio_tg_status_first_err_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_14;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_14;
  wire                        vio_tg_status_first_exp_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_14;
  wire                        vio_tg_status_first_read_bit_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_14;
  wire                        vio_tg_status_err_bit_sticky_valid_14;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_14;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_14;
  wire                        vio_tg_status_err_type_valid_14;
  wire                        vio_tg_status_err_type_14;
  wire                        vio_tg_status_wr_done_14;
  wire                        vio_tg_status_watch_dog_hang_14;
  wire                        tg_ila_debug_14;
  reg  [4:0]                  wr_cnt_14;
  reg  [4:0]                  rd_cnt_14;

  wire                        vio_tg_rst_15;
  wire                        vio_tg_start_15;
  wire                        vio_tg_err_chk_en_15;
  wire                        vio_tg_err_clear_15;
  wire [3:0]                  vio_tg_instr_addr_mode_15;
  wire [3:0]                  vio_tg_instr_data_mode_15;
  wire [3:0]                  vio_tg_instr_rw_mode_15;
  wire [1:0]                  vio_tg_instr_rw_submode_15;
  wire [31:0]                 vio_tg_instr_num_of_iter_15;
  wire [5:0]                  vio_tg_instr_nxt_instr_15;
  wire                        vio_tg_restart_15;
  wire                        vio_tg_pause_15;
  wire                        vio_tg_err_clear_all_15;
  wire                        vio_tg_err_continue_15;
  wire                        vio_tg_instr_program_en_15;
  wire                        vio_tg_direct_instr_en_15;
  wire [4:0]                  vio_tg_instr_num_15;
  wire [2:0]                  vio_tg_instr_victim_mode_15;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_15;
  wire [2:0]                  vio_tg_instr_victim_select_15;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_15;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_15;
  wire                        vio_tg_seed_program_en_15;
  wire [7:0]                  vio_tg_seed_num_15;
  wire [22:0]                 vio_tg_seed_15;
  wire [7:0]                  vio_tg_glb_victim_bit_15;
  wire [32:0]                 vio_tg_glb_start_addr_15;
  wire [3:0]                  vio_tg_status_state_15;
  wire                        vio_tg_status_err_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_15;
  wire [31:0]                 vio_tg_status_err_cnt_15;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_15;
  wire                        vio_tg_status_exp_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_15;
  wire                        vio_tg_status_read_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_15;
  wire                        vio_tg_status_first_err_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_15;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_15;
  wire                        vio_tg_status_first_exp_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_15;
  wire                        vio_tg_status_first_read_bit_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_15;
  wire                        vio_tg_status_err_bit_sticky_valid_15;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_15;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_15;
  wire                        vio_tg_status_err_type_valid_15;
  wire                        vio_tg_status_err_type_15;
  wire                        vio_tg_status_wr_done_15;
  wire                        vio_tg_status_watch_dog_hang_15;
  wire                        tg_ila_debug_15;
  reg  [4:0]                  wr_cnt_15;
  reg  [4:0]                  rd_cnt_15;



////////////////////////////////////////////////////////////////////////////////
// Reg declaration
////////////////////////////////////////////////////////////////////////////////
reg  [3:0]                                          cnt_rst_0;
reg           axi_rst_0_r1_n;
reg           axi_rst_0_mmcm_n;
(* keep = "TRUE" *) reg           axi_rst_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst0_st0_r1_n, axi_rst0_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst0_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst1_st0_r1_n, axi_rst1_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst1_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst2_st0_r1_n, axi_rst2_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst2_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst3_st0_r1_n, axi_rst3_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst3_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst4_st0_r1_n, axi_rst4_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst4_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst5_st0_r1_n, axi_rst5_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst5_st0_n;
// (* ASYNC_REG = "TRUE" *) reg           axi_rst6_st0_r1_n, axi_rst6_st0_r2_n;
// (* keep = "TRUE" *) reg           axi_rst6_st0_n;


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


////////////////////////////////////////////////////////////////////////////////
// Calculating Write Data Parity
////////////////////////////////////////////////////////////////////////////////
assign AXI_00_WDATA_PARITY_i = {{^(AXI_00_WDATA[255:248])},{^(AXI_00_WDATA[247:240])},{^(AXI_00_WDATA[239:232])},{^(AXI_00_WDATA[231:224])},
                              {^(AXI_00_WDATA[223:216])},{^(AXI_00_WDATA[215:208])},{^(AXI_00_WDATA[207:200])},{^(AXI_00_WDATA[199:192])},
                              {^(AXI_00_WDATA[191:184])},{^(AXI_00_WDATA[183:176])},{^(AXI_00_WDATA[175:168])},{^(AXI_00_WDATA[167:160])},
                              {^(AXI_00_WDATA[159:152])},{^(AXI_00_WDATA[151:144])},{^(AXI_00_WDATA[143:136])},{^(AXI_00_WDATA[135:128])},
                              {^(AXI_00_WDATA[127:120])},{^(AXI_00_WDATA[119:112])},{^(AXI_00_WDATA[111:104])},{^(AXI_00_WDATA[103:96])},
                              {^(AXI_00_WDATA[95:88])},  {^(AXI_00_WDATA[87:80])},  {^(AXI_00_WDATA[79:72])},  {^(AXI_00_WDATA[71:64])},
                              {^(AXI_00_WDATA[63:56])},  {^(AXI_00_WDATA[55:48])},  {^(AXI_00_WDATA[47:40])},  {^(AXI_00_WDATA[39:32])},
                              {^(AXI_00_WDATA[31:24])},  {^(AXI_00_WDATA[23:16])},  {^(AXI_00_WDATA[15:8])},   {^(AXI_00_WDATA[7:0])}};

always @(posedge AXI_ACLK0_st0_buf)
  AXI_00_WDATA_PARITY <= AXI_00_WDATA_PARITY_i;

assign AXI_01_WDATA_PARITY_i = {{^(AXI_01_WDATA[255:248])},{^(AXI_01_WDATA[247:240])},{^(AXI_01_WDATA[239:232])},{^(AXI_01_WDATA[231:224])},
                              {^(AXI_01_WDATA[223:216])},{^(AXI_01_WDATA[215:208])},{^(AXI_01_WDATA[207:200])},{^(AXI_01_WDATA[199:192])},
                              {^(AXI_01_WDATA[191:184])},{^(AXI_01_WDATA[183:176])},{^(AXI_01_WDATA[175:168])},{^(AXI_01_WDATA[167:160])},
                              {^(AXI_01_WDATA[159:152])},{^(AXI_01_WDATA[151:144])},{^(AXI_01_WDATA[143:136])},{^(AXI_01_WDATA[135:128])},
                              {^(AXI_01_WDATA[127:120])},{^(AXI_01_WDATA[119:112])},{^(AXI_01_WDATA[111:104])},{^(AXI_01_WDATA[103:96])},
                              {^(AXI_01_WDATA[95:88])},  {^(AXI_01_WDATA[87:80])},  {^(AXI_01_WDATA[79:72])},  {^(AXI_01_WDATA[71:64])},
                              {^(AXI_01_WDATA[63:56])},  {^(AXI_01_WDATA[55:48])},  {^(AXI_01_WDATA[47:40])},  {^(AXI_01_WDATA[39:32])},
                              {^(AXI_01_WDATA[31:24])},  {^(AXI_01_WDATA[23:16])},  {^(AXI_01_WDATA[15:8])},   {^(AXI_01_WDATA[7:0])}};

always @(posedge AXI_ACLK0_st0_buf)
  AXI_01_WDATA_PARITY <= AXI_01_WDATA_PARITY_i;
assign AXI_02_WDATA_PARITY_i = {{^(AXI_02_WDATA[255:248])},{^(AXI_02_WDATA[247:240])},{^(AXI_02_WDATA[239:232])},{^(AXI_02_WDATA[231:224])},
                              {^(AXI_02_WDATA[223:216])},{^(AXI_02_WDATA[215:208])},{^(AXI_02_WDATA[207:200])},{^(AXI_02_WDATA[199:192])},
                              {^(AXI_02_WDATA[191:184])},{^(AXI_02_WDATA[183:176])},{^(AXI_02_WDATA[175:168])},{^(AXI_02_WDATA[167:160])},
                              {^(AXI_02_WDATA[159:152])},{^(AXI_02_WDATA[151:144])},{^(AXI_02_WDATA[143:136])},{^(AXI_02_WDATA[135:128])},
                              {^(AXI_02_WDATA[127:120])},{^(AXI_02_WDATA[119:112])},{^(AXI_02_WDATA[111:104])},{^(AXI_02_WDATA[103:96])},
                              {^(AXI_02_WDATA[95:88])},  {^(AXI_02_WDATA[87:80])},  {^(AXI_02_WDATA[79:72])},  {^(AXI_02_WDATA[71:64])},
                              {^(AXI_02_WDATA[63:56])},  {^(AXI_02_WDATA[55:48])},  {^(AXI_02_WDATA[47:40])},  {^(AXI_02_WDATA[39:32])},
                              {^(AXI_02_WDATA[31:24])},  {^(AXI_02_WDATA[23:16])},  {^(AXI_02_WDATA[15:8])},   {^(AXI_02_WDATA[7:0])}};

always @(posedge AXI_ACLK1_st0_buf)
  AXI_02_WDATA_PARITY <= AXI_02_WDATA_PARITY_i;
assign AXI_03_WDATA_PARITY_i = {{^(AXI_03_WDATA[255:248])},{^(AXI_03_WDATA[247:240])},{^(AXI_03_WDATA[239:232])},{^(AXI_03_WDATA[231:224])},
                              {^(AXI_03_WDATA[223:216])},{^(AXI_03_WDATA[215:208])},{^(AXI_03_WDATA[207:200])},{^(AXI_03_WDATA[199:192])},
                              {^(AXI_03_WDATA[191:184])},{^(AXI_03_WDATA[183:176])},{^(AXI_03_WDATA[175:168])},{^(AXI_03_WDATA[167:160])},
                              {^(AXI_03_WDATA[159:152])},{^(AXI_03_WDATA[151:144])},{^(AXI_03_WDATA[143:136])},{^(AXI_03_WDATA[135:128])},
                              {^(AXI_03_WDATA[127:120])},{^(AXI_03_WDATA[119:112])},{^(AXI_03_WDATA[111:104])},{^(AXI_03_WDATA[103:96])},
                              {^(AXI_03_WDATA[95:88])},  {^(AXI_03_WDATA[87:80])},  {^(AXI_03_WDATA[79:72])},  {^(AXI_03_WDATA[71:64])},
                              {^(AXI_03_WDATA[63:56])},  {^(AXI_03_WDATA[55:48])},  {^(AXI_03_WDATA[47:40])},  {^(AXI_03_WDATA[39:32])},
                              {^(AXI_03_WDATA[31:24])},  {^(AXI_03_WDATA[23:16])},  {^(AXI_03_WDATA[15:8])},   {^(AXI_03_WDATA[7:0])}};

always @(posedge AXI_ACLK1_st0_buf)
  AXI_03_WDATA_PARITY <= AXI_03_WDATA_PARITY_i;
assign AXI_04_WDATA_PARITY_i = {{^(AXI_04_WDATA[255:248])},{^(AXI_04_WDATA[247:240])},{^(AXI_04_WDATA[239:232])},{^(AXI_04_WDATA[231:224])},
                              {^(AXI_04_WDATA[223:216])},{^(AXI_04_WDATA[215:208])},{^(AXI_04_WDATA[207:200])},{^(AXI_04_WDATA[199:192])},
                              {^(AXI_04_WDATA[191:184])},{^(AXI_04_WDATA[183:176])},{^(AXI_04_WDATA[175:168])},{^(AXI_04_WDATA[167:160])},
                              {^(AXI_04_WDATA[159:152])},{^(AXI_04_WDATA[151:144])},{^(AXI_04_WDATA[143:136])},{^(AXI_04_WDATA[135:128])},
                              {^(AXI_04_WDATA[127:120])},{^(AXI_04_WDATA[119:112])},{^(AXI_04_WDATA[111:104])},{^(AXI_04_WDATA[103:96])},
                              {^(AXI_04_WDATA[95:88])},  {^(AXI_04_WDATA[87:80])},  {^(AXI_04_WDATA[79:72])},  {^(AXI_04_WDATA[71:64])},
                              {^(AXI_04_WDATA[63:56])},  {^(AXI_04_WDATA[55:48])},  {^(AXI_04_WDATA[47:40])},  {^(AXI_04_WDATA[39:32])},
                              {^(AXI_04_WDATA[31:24])},  {^(AXI_04_WDATA[23:16])},  {^(AXI_04_WDATA[15:8])},   {^(AXI_04_WDATA[7:0])}};

always @(posedge AXI_ACLK2_st0_buf)
  AXI_04_WDATA_PARITY <= AXI_04_WDATA_PARITY_i;
assign AXI_05_WDATA_PARITY_i = {{^(AXI_05_WDATA[255:248])},{^(AXI_05_WDATA[247:240])},{^(AXI_05_WDATA[239:232])},{^(AXI_05_WDATA[231:224])},
                              {^(AXI_05_WDATA[223:216])},{^(AXI_05_WDATA[215:208])},{^(AXI_05_WDATA[207:200])},{^(AXI_05_WDATA[199:192])},
                              {^(AXI_05_WDATA[191:184])},{^(AXI_05_WDATA[183:176])},{^(AXI_05_WDATA[175:168])},{^(AXI_05_WDATA[167:160])},
                              {^(AXI_05_WDATA[159:152])},{^(AXI_05_WDATA[151:144])},{^(AXI_05_WDATA[143:136])},{^(AXI_05_WDATA[135:128])},
                              {^(AXI_05_WDATA[127:120])},{^(AXI_05_WDATA[119:112])},{^(AXI_05_WDATA[111:104])},{^(AXI_05_WDATA[103:96])},
                              {^(AXI_05_WDATA[95:88])},  {^(AXI_05_WDATA[87:80])},  {^(AXI_05_WDATA[79:72])},  {^(AXI_05_WDATA[71:64])},
                              {^(AXI_05_WDATA[63:56])},  {^(AXI_05_WDATA[55:48])},  {^(AXI_05_WDATA[47:40])},  {^(AXI_05_WDATA[39:32])},
                              {^(AXI_05_WDATA[31:24])},  {^(AXI_05_WDATA[23:16])},  {^(AXI_05_WDATA[15:8])},   {^(AXI_05_WDATA[7:0])}};

always @(posedge AXI_ACLK2_st0_buf)
  AXI_05_WDATA_PARITY <= AXI_05_WDATA_PARITY_i;
assign AXI_06_WDATA_PARITY_i = {{^(AXI_06_WDATA[255:248])},{^(AXI_06_WDATA[247:240])},{^(AXI_06_WDATA[239:232])},{^(AXI_06_WDATA[231:224])},
                              {^(AXI_06_WDATA[223:216])},{^(AXI_06_WDATA[215:208])},{^(AXI_06_WDATA[207:200])},{^(AXI_06_WDATA[199:192])},
                              {^(AXI_06_WDATA[191:184])},{^(AXI_06_WDATA[183:176])},{^(AXI_06_WDATA[175:168])},{^(AXI_06_WDATA[167:160])},
                              {^(AXI_06_WDATA[159:152])},{^(AXI_06_WDATA[151:144])},{^(AXI_06_WDATA[143:136])},{^(AXI_06_WDATA[135:128])},
                              {^(AXI_06_WDATA[127:120])},{^(AXI_06_WDATA[119:112])},{^(AXI_06_WDATA[111:104])},{^(AXI_06_WDATA[103:96])},
                              {^(AXI_06_WDATA[95:88])},  {^(AXI_06_WDATA[87:80])},  {^(AXI_06_WDATA[79:72])},  {^(AXI_06_WDATA[71:64])},
                              {^(AXI_06_WDATA[63:56])},  {^(AXI_06_WDATA[55:48])},  {^(AXI_06_WDATA[47:40])},  {^(AXI_06_WDATA[39:32])},
                              {^(AXI_06_WDATA[31:24])},  {^(AXI_06_WDATA[23:16])},  {^(AXI_06_WDATA[15:8])},   {^(AXI_06_WDATA[7:0])}};

always @(posedge AXI_ACLK3_st0_buf)
  AXI_06_WDATA_PARITY <= AXI_06_WDATA_PARITY_i;
assign AXI_07_WDATA_PARITY_i = {{^(AXI_07_WDATA[255:248])},{^(AXI_07_WDATA[247:240])},{^(AXI_07_WDATA[239:232])},{^(AXI_07_WDATA[231:224])},
                              {^(AXI_07_WDATA[223:216])},{^(AXI_07_WDATA[215:208])},{^(AXI_07_WDATA[207:200])},{^(AXI_07_WDATA[199:192])},
                              {^(AXI_07_WDATA[191:184])},{^(AXI_07_WDATA[183:176])},{^(AXI_07_WDATA[175:168])},{^(AXI_07_WDATA[167:160])},
                              {^(AXI_07_WDATA[159:152])},{^(AXI_07_WDATA[151:144])},{^(AXI_07_WDATA[143:136])},{^(AXI_07_WDATA[135:128])},
                              {^(AXI_07_WDATA[127:120])},{^(AXI_07_WDATA[119:112])},{^(AXI_07_WDATA[111:104])},{^(AXI_07_WDATA[103:96])},
                              {^(AXI_07_WDATA[95:88])},  {^(AXI_07_WDATA[87:80])},  {^(AXI_07_WDATA[79:72])},  {^(AXI_07_WDATA[71:64])},
                              {^(AXI_07_WDATA[63:56])},  {^(AXI_07_WDATA[55:48])},  {^(AXI_07_WDATA[47:40])},  {^(AXI_07_WDATA[39:32])},
                              {^(AXI_07_WDATA[31:24])},  {^(AXI_07_WDATA[23:16])},  {^(AXI_07_WDATA[15:8])},   {^(AXI_07_WDATA[7:0])}};

always @(posedge AXI_ACLK3_st0_buf)
  AXI_07_WDATA_PARITY <= AXI_07_WDATA_PARITY_i;
assign AXI_08_WDATA_PARITY_i = {{^(AXI_08_WDATA[255:248])},{^(AXI_08_WDATA[247:240])},{^(AXI_08_WDATA[239:232])},{^(AXI_08_WDATA[231:224])},
                              {^(AXI_08_WDATA[223:216])},{^(AXI_08_WDATA[215:208])},{^(AXI_08_WDATA[207:200])},{^(AXI_08_WDATA[199:192])},
                              {^(AXI_08_WDATA[191:184])},{^(AXI_08_WDATA[183:176])},{^(AXI_08_WDATA[175:168])},{^(AXI_08_WDATA[167:160])},
                              {^(AXI_08_WDATA[159:152])},{^(AXI_08_WDATA[151:144])},{^(AXI_08_WDATA[143:136])},{^(AXI_08_WDATA[135:128])},
                              {^(AXI_08_WDATA[127:120])},{^(AXI_08_WDATA[119:112])},{^(AXI_08_WDATA[111:104])},{^(AXI_08_WDATA[103:96])},
                              {^(AXI_08_WDATA[95:88])},  {^(AXI_08_WDATA[87:80])},  {^(AXI_08_WDATA[79:72])},  {^(AXI_08_WDATA[71:64])},
                              {^(AXI_08_WDATA[63:56])},  {^(AXI_08_WDATA[55:48])},  {^(AXI_08_WDATA[47:40])},  {^(AXI_08_WDATA[39:32])},
                              {^(AXI_08_WDATA[31:24])},  {^(AXI_08_WDATA[23:16])},  {^(AXI_08_WDATA[15:8])},   {^(AXI_08_WDATA[7:0])}};

always @(posedge AXI_ACLK4_st0_buf)
  AXI_08_WDATA_PARITY <= AXI_08_WDATA_PARITY_i;
assign AXI_09_WDATA_PARITY_i = {{^(AXI_09_WDATA[255:248])},{^(AXI_09_WDATA[247:240])},{^(AXI_09_WDATA[239:232])},{^(AXI_09_WDATA[231:224])},
                              {^(AXI_09_WDATA[223:216])},{^(AXI_09_WDATA[215:208])},{^(AXI_09_WDATA[207:200])},{^(AXI_09_WDATA[199:192])},
                              {^(AXI_09_WDATA[191:184])},{^(AXI_09_WDATA[183:176])},{^(AXI_09_WDATA[175:168])},{^(AXI_09_WDATA[167:160])},
                              {^(AXI_09_WDATA[159:152])},{^(AXI_09_WDATA[151:144])},{^(AXI_09_WDATA[143:136])},{^(AXI_09_WDATA[135:128])},
                              {^(AXI_09_WDATA[127:120])},{^(AXI_09_WDATA[119:112])},{^(AXI_09_WDATA[111:104])},{^(AXI_09_WDATA[103:96])},
                              {^(AXI_09_WDATA[95:88])},  {^(AXI_09_WDATA[87:80])},  {^(AXI_09_WDATA[79:72])},  {^(AXI_09_WDATA[71:64])},
                              {^(AXI_09_WDATA[63:56])},  {^(AXI_09_WDATA[55:48])},  {^(AXI_09_WDATA[47:40])},  {^(AXI_09_WDATA[39:32])},
                              {^(AXI_09_WDATA[31:24])},  {^(AXI_09_WDATA[23:16])},  {^(AXI_09_WDATA[15:8])},   {^(AXI_09_WDATA[7:0])}};

always @(posedge AXI_ACLK4_st0_buf)
  AXI_09_WDATA_PARITY <= AXI_09_WDATA_PARITY_i;
assign AXI_10_WDATA_PARITY_i = {{^(AXI_10_WDATA[255:248])},{^(AXI_10_WDATA[247:240])},{^(AXI_10_WDATA[239:232])},{^(AXI_10_WDATA[231:224])},
                              {^(AXI_10_WDATA[223:216])},{^(AXI_10_WDATA[215:208])},{^(AXI_10_WDATA[207:200])},{^(AXI_10_WDATA[199:192])},
                              {^(AXI_10_WDATA[191:184])},{^(AXI_10_WDATA[183:176])},{^(AXI_10_WDATA[175:168])},{^(AXI_10_WDATA[167:160])},
                              {^(AXI_10_WDATA[159:152])},{^(AXI_10_WDATA[151:144])},{^(AXI_10_WDATA[143:136])},{^(AXI_10_WDATA[135:128])},
                              {^(AXI_10_WDATA[127:120])},{^(AXI_10_WDATA[119:112])},{^(AXI_10_WDATA[111:104])},{^(AXI_10_WDATA[103:96])},
                              {^(AXI_10_WDATA[95:88])},  {^(AXI_10_WDATA[87:80])},  {^(AXI_10_WDATA[79:72])},  {^(AXI_10_WDATA[71:64])},
                              {^(AXI_10_WDATA[63:56])},  {^(AXI_10_WDATA[55:48])},  {^(AXI_10_WDATA[47:40])},  {^(AXI_10_WDATA[39:32])},
                              {^(AXI_10_WDATA[31:24])},  {^(AXI_10_WDATA[23:16])},  {^(AXI_10_WDATA[15:8])},   {^(AXI_10_WDATA[7:0])}};

always @(posedge AXI_ACLK5_st0_buf)
  AXI_10_WDATA_PARITY <= AXI_10_WDATA_PARITY_i;
assign AXI_11_WDATA_PARITY_i = {{^(AXI_11_WDATA[255:248])},{^(AXI_11_WDATA[247:240])},{^(AXI_11_WDATA[239:232])},{^(AXI_11_WDATA[231:224])},
                              {^(AXI_11_WDATA[223:216])},{^(AXI_11_WDATA[215:208])},{^(AXI_11_WDATA[207:200])},{^(AXI_11_WDATA[199:192])},
                              {^(AXI_11_WDATA[191:184])},{^(AXI_11_WDATA[183:176])},{^(AXI_11_WDATA[175:168])},{^(AXI_11_WDATA[167:160])},
                              {^(AXI_11_WDATA[159:152])},{^(AXI_11_WDATA[151:144])},{^(AXI_11_WDATA[143:136])},{^(AXI_11_WDATA[135:128])},
                              {^(AXI_11_WDATA[127:120])},{^(AXI_11_WDATA[119:112])},{^(AXI_11_WDATA[111:104])},{^(AXI_11_WDATA[103:96])},
                              {^(AXI_11_WDATA[95:88])},  {^(AXI_11_WDATA[87:80])},  {^(AXI_11_WDATA[79:72])},  {^(AXI_11_WDATA[71:64])},
                              {^(AXI_11_WDATA[63:56])},  {^(AXI_11_WDATA[55:48])},  {^(AXI_11_WDATA[47:40])},  {^(AXI_11_WDATA[39:32])},
                              {^(AXI_11_WDATA[31:24])},  {^(AXI_11_WDATA[23:16])},  {^(AXI_11_WDATA[15:8])},   {^(AXI_11_WDATA[7:0])}};

always @(posedge AXI_ACLK5_st0_buf)
  AXI_11_WDATA_PARITY <= AXI_11_WDATA_PARITY_i;
assign AXI_12_WDATA_PARITY_i = {{^(AXI_12_WDATA[255:248])},{^(AXI_12_WDATA[247:240])},{^(AXI_12_WDATA[239:232])},{^(AXI_12_WDATA[231:224])},
                              {^(AXI_12_WDATA[223:216])},{^(AXI_12_WDATA[215:208])},{^(AXI_12_WDATA[207:200])},{^(AXI_12_WDATA[199:192])},
                              {^(AXI_12_WDATA[191:184])},{^(AXI_12_WDATA[183:176])},{^(AXI_12_WDATA[175:168])},{^(AXI_12_WDATA[167:160])},
                              {^(AXI_12_WDATA[159:152])},{^(AXI_12_WDATA[151:144])},{^(AXI_12_WDATA[143:136])},{^(AXI_12_WDATA[135:128])},
                              {^(AXI_12_WDATA[127:120])},{^(AXI_12_WDATA[119:112])},{^(AXI_12_WDATA[111:104])},{^(AXI_12_WDATA[103:96])},
                              {^(AXI_12_WDATA[95:88])},  {^(AXI_12_WDATA[87:80])},  {^(AXI_12_WDATA[79:72])},  {^(AXI_12_WDATA[71:64])},
                              {^(AXI_12_WDATA[63:56])},  {^(AXI_12_WDATA[55:48])},  {^(AXI_12_WDATA[47:40])},  {^(AXI_12_WDATA[39:32])},
                              {^(AXI_12_WDATA[31:24])},  {^(AXI_12_WDATA[23:16])},  {^(AXI_12_WDATA[15:8])},   {^(AXI_12_WDATA[7:0])}};

always @(posedge AXI_ACLK5_st0_buf)
  AXI_12_WDATA_PARITY <= AXI_12_WDATA_PARITY_i;
assign AXI_13_WDATA_PARITY_i = {{^(AXI_13_WDATA[255:248])},{^(AXI_13_WDATA[247:240])},{^(AXI_13_WDATA[239:232])},{^(AXI_13_WDATA[231:224])},
                              {^(AXI_13_WDATA[223:216])},{^(AXI_13_WDATA[215:208])},{^(AXI_13_WDATA[207:200])},{^(AXI_13_WDATA[199:192])},
                              {^(AXI_13_WDATA[191:184])},{^(AXI_13_WDATA[183:176])},{^(AXI_13_WDATA[175:168])},{^(AXI_13_WDATA[167:160])},
                              {^(AXI_13_WDATA[159:152])},{^(AXI_13_WDATA[151:144])},{^(AXI_13_WDATA[143:136])},{^(AXI_13_WDATA[135:128])},
                              {^(AXI_13_WDATA[127:120])},{^(AXI_13_WDATA[119:112])},{^(AXI_13_WDATA[111:104])},{^(AXI_13_WDATA[103:96])},
                              {^(AXI_13_WDATA[95:88])},  {^(AXI_13_WDATA[87:80])},  {^(AXI_13_WDATA[79:72])},  {^(AXI_13_WDATA[71:64])},
                              {^(AXI_13_WDATA[63:56])},  {^(AXI_13_WDATA[55:48])},  {^(AXI_13_WDATA[47:40])},  {^(AXI_13_WDATA[39:32])},
                              {^(AXI_13_WDATA[31:24])},  {^(AXI_13_WDATA[23:16])},  {^(AXI_13_WDATA[15:8])},   {^(AXI_13_WDATA[7:0])}};

always @(posedge AXI_ACLK6_st0_buf)
  AXI_13_WDATA_PARITY <= AXI_13_WDATA_PARITY_i;
assign AXI_14_WDATA_PARITY_i = {{^(AXI_14_WDATA[255:248])},{^(AXI_14_WDATA[247:240])},{^(AXI_14_WDATA[239:232])},{^(AXI_14_WDATA[231:224])},
                              {^(AXI_14_WDATA[223:216])},{^(AXI_14_WDATA[215:208])},{^(AXI_14_WDATA[207:200])},{^(AXI_14_WDATA[199:192])},
                              {^(AXI_14_WDATA[191:184])},{^(AXI_14_WDATA[183:176])},{^(AXI_14_WDATA[175:168])},{^(AXI_14_WDATA[167:160])},
                              {^(AXI_14_WDATA[159:152])},{^(AXI_14_WDATA[151:144])},{^(AXI_14_WDATA[143:136])},{^(AXI_14_WDATA[135:128])},
                              {^(AXI_14_WDATA[127:120])},{^(AXI_14_WDATA[119:112])},{^(AXI_14_WDATA[111:104])},{^(AXI_14_WDATA[103:96])},
                              {^(AXI_14_WDATA[95:88])},  {^(AXI_14_WDATA[87:80])},  {^(AXI_14_WDATA[79:72])},  {^(AXI_14_WDATA[71:64])},
                              {^(AXI_14_WDATA[63:56])},  {^(AXI_14_WDATA[55:48])},  {^(AXI_14_WDATA[47:40])},  {^(AXI_14_WDATA[39:32])},
                              {^(AXI_14_WDATA[31:24])},  {^(AXI_14_WDATA[23:16])},  {^(AXI_14_WDATA[15:8])},   {^(AXI_14_WDATA[7:0])}};

always @(posedge AXI_ACLK6_st0_buf)
  AXI_14_WDATA_PARITY <= AXI_14_WDATA_PARITY_i;
assign AXI_15_WDATA_PARITY_i = {{^(AXI_15_WDATA[255:248])},{^(AXI_15_WDATA[247:240])},{^(AXI_15_WDATA[239:232])},{^(AXI_15_WDATA[231:224])},
                              {^(AXI_15_WDATA[223:216])},{^(AXI_15_WDATA[215:208])},{^(AXI_15_WDATA[207:200])},{^(AXI_15_WDATA[199:192])},
                              {^(AXI_15_WDATA[191:184])},{^(AXI_15_WDATA[183:176])},{^(AXI_15_WDATA[175:168])},{^(AXI_15_WDATA[167:160])},
                              {^(AXI_15_WDATA[159:152])},{^(AXI_15_WDATA[151:144])},{^(AXI_15_WDATA[143:136])},{^(AXI_15_WDATA[135:128])},
                              {^(AXI_15_WDATA[127:120])},{^(AXI_15_WDATA[119:112])},{^(AXI_15_WDATA[111:104])},{^(AXI_15_WDATA[103:96])},
                              {^(AXI_15_WDATA[95:88])},  {^(AXI_15_WDATA[87:80])},  {^(AXI_15_WDATA[79:72])},  {^(AXI_15_WDATA[71:64])},
                              {^(AXI_15_WDATA[63:56])},  {^(AXI_15_WDATA[55:48])},  {^(AXI_15_WDATA[47:40])},  {^(AXI_15_WDATA[39:32])},
                              {^(AXI_15_WDATA[31:24])},  {^(AXI_15_WDATA[23:16])},  {^(AXI_15_WDATA[15:8])},   {^(AXI_15_WDATA[7:0])}};

always @(posedge AXI_ACLK6_st0_buf)
  AXI_15_WDATA_PARITY <= AXI_15_WDATA_PARITY_i;

////////////////////////////////////////////////////////////////////////////////
// Instantiating User Design
////////////////////////////////////////////////////////////////////////////////
hbm_0 u_hbm_0
(
  .HBM_REF_CLK_0                 (HBM_REF_CLK_0)

  ,.AXI_00_ACLK                  (AXI_ACLK0_st0_buf     )
  ,.AXI_00_ARESET_N              (axi_rst0_st0_n        )
  ,.AXI_00_ARADDR                (AXI_00_ARADDR      )
  ,.AXI_00_ARBURST               (AXI_00_ARBURST     )
  ,.AXI_00_ARID                  (AXI_00_ARID        )
  ,.AXI_00_ARLEN                 (AXI_00_ARLEN[3:0]  )
  ,.AXI_00_ARSIZE                (AXI_00_ARSIZE      )
  ,.AXI_00_ARVALID               (AXI_00_ARVALID     )
  ,.AXI_00_AWADDR                (AXI_00_AWADDR      )
  ,.AXI_00_AWBURST               (AXI_00_AWBURST     )
  ,.AXI_00_AWID                  (AXI_00_AWID        )
  ,.AXI_00_AWLEN                 (AXI_00_AWLEN[3:0]  )
  ,.AXI_00_AWSIZE                (AXI_00_AWSIZE      )
  ,.AXI_00_AWVALID               (AXI_00_AWVALID     )
  ,.AXI_00_RREADY                (AXI_00_RREADY      )
  ,.AXI_00_BREADY                (AXI_00_BREADY      )
  ,.AXI_00_WDATA                 (AXI_00_WDATA       )
  ,.AXI_00_WLAST                 (AXI_00_WLAST       )
  ,.AXI_00_WSTRB                 (AXI_00_WSTRB       )
  ,.AXI_00_WDATA_PARITY          (AXI_00_WDATA_PARITY_i)
  ,.AXI_00_WVALID                (AXI_00_WVALID      )

  ,.AXI_01_ACLK                  (AXI_ACLK0_st0_buf     )
  ,.AXI_01_ARESET_N              (axi_rst0_st0_n        )
  ,.AXI_01_ARADDR                (AXI_01_ARADDR      )
  ,.AXI_01_ARBURST               (AXI_01_ARBURST     )
  ,.AXI_01_ARID                  (AXI_01_ARID        )
  ,.AXI_01_ARLEN                 (AXI_01_ARLEN[3:0]  )
  ,.AXI_01_ARSIZE                (AXI_01_ARSIZE      )
  ,.AXI_01_ARVALID               (AXI_01_ARVALID     )
  ,.AXI_01_AWADDR                (AXI_01_AWADDR      )
  ,.AXI_01_AWBURST               (AXI_01_AWBURST     )
  ,.AXI_01_AWID                  (AXI_01_AWID        )
  ,.AXI_01_AWLEN                 (AXI_01_AWLEN[3:0]  )
  ,.AXI_01_AWSIZE                (AXI_01_AWSIZE      )
  ,.AXI_01_AWVALID               (AXI_01_AWVALID     )
  ,.AXI_01_RREADY                (AXI_01_RREADY      )
  ,.AXI_01_BREADY                (AXI_01_BREADY      )
  ,.AXI_01_WDATA                 (AXI_01_WDATA       )
  ,.AXI_01_WLAST                 (AXI_01_WLAST       )
  ,.AXI_01_WSTRB                 (AXI_01_WSTRB       )
  ,.AXI_01_WDATA_PARITY          (AXI_01_WDATA_PARITY_i)
  ,.AXI_01_WVALID                (AXI_01_WVALID      )

  ,.AXI_02_ACLK                  (AXI_ACLK1_st0_buf     )
  ,.AXI_02_ARESET_N              (axi_rst1_st0_n        )
  ,.AXI_02_ARADDR                (AXI_02_ARADDR      )
  ,.AXI_02_ARBURST               (AXI_02_ARBURST     )
  ,.AXI_02_ARID                  (AXI_02_ARID        )
  ,.AXI_02_ARLEN                 (AXI_02_ARLEN[3:0]  )
  ,.AXI_02_ARSIZE                (AXI_02_ARSIZE      )
  ,.AXI_02_ARVALID               (AXI_02_ARVALID     )
  ,.AXI_02_AWADDR                (AXI_02_AWADDR      )
  ,.AXI_02_AWBURST               (AXI_02_AWBURST     )
  ,.AXI_02_AWID                  (AXI_02_AWID        )
  ,.AXI_02_AWLEN                 (AXI_02_AWLEN[3:0]  )
  ,.AXI_02_AWSIZE                (AXI_02_AWSIZE      )
  ,.AXI_02_AWVALID               (AXI_02_AWVALID     )
  ,.AXI_02_RREADY                (AXI_02_RREADY      )
  ,.AXI_02_BREADY                (AXI_02_BREADY      )
  ,.AXI_02_WDATA                 (AXI_02_WDATA       )
  ,.AXI_02_WLAST                 (AXI_02_WLAST       )
  ,.AXI_02_WSTRB                 (AXI_02_WSTRB       )
  ,.AXI_02_WDATA_PARITY          (AXI_02_WDATA_PARITY_i)
  ,.AXI_02_WVALID                (AXI_02_WVALID      )
  ,.AXI_03_ACLK                  (AXI_ACLK1_st0_buf     )
  ,.AXI_03_ARESET_N              (axi_rst1_st0_n        )
  ,.AXI_03_ARADDR                (AXI_03_ARADDR      )
  ,.AXI_03_ARBURST               (AXI_03_ARBURST     )
  ,.AXI_03_ARID                  (AXI_03_ARID        )
  ,.AXI_03_ARLEN                 (AXI_03_ARLEN[3:0]  )
  ,.AXI_03_ARSIZE                (AXI_03_ARSIZE      )
  ,.AXI_03_ARVALID               (AXI_03_ARVALID     )
  ,.AXI_03_AWADDR                (AXI_03_AWADDR      )
  ,.AXI_03_AWBURST               (AXI_03_AWBURST     )
  ,.AXI_03_AWID                  (AXI_03_AWID        )
  ,.AXI_03_AWLEN                 (AXI_03_AWLEN[3:0]  )
  ,.AXI_03_AWSIZE                (AXI_03_AWSIZE      )
  ,.AXI_03_AWVALID               (AXI_03_AWVALID     )
  ,.AXI_03_RREADY                (AXI_03_RREADY      )
  ,.AXI_03_BREADY                (AXI_03_BREADY      )
  ,.AXI_03_WDATA                 (AXI_03_WDATA       )
  ,.AXI_03_WLAST                 (AXI_03_WLAST       )
  ,.AXI_03_WSTRB                 (AXI_03_WSTRB       )
  ,.AXI_03_WDATA_PARITY          (AXI_03_WDATA_PARITY_i)
  ,.AXI_03_WVALID                (AXI_03_WVALID      )
  ,.AXI_04_ACLK                  (AXI_ACLK2_st0_buf     )
  ,.AXI_04_ARESET_N              (axi_rst2_st0_n        )
  ,.AXI_04_ARADDR                (AXI_04_ARADDR      )
  ,.AXI_04_ARBURST               (AXI_04_ARBURST     )
  ,.AXI_04_ARID                  (AXI_04_ARID        )
  ,.AXI_04_ARLEN                 (AXI_04_ARLEN[3:0]  )
  ,.AXI_04_ARSIZE                (AXI_04_ARSIZE      )
  ,.AXI_04_ARVALID               (AXI_04_ARVALID     )
  ,.AXI_04_AWADDR                (AXI_04_AWADDR      )
  ,.AXI_04_AWBURST               (AXI_04_AWBURST     )
  ,.AXI_04_AWID                  (AXI_04_AWID        )
  ,.AXI_04_AWLEN                 (AXI_04_AWLEN[3:0]  )
  ,.AXI_04_AWSIZE                (AXI_04_AWSIZE      )
  ,.AXI_04_AWVALID               (AXI_04_AWVALID     )
  ,.AXI_04_RREADY                (AXI_04_RREADY      )
  ,.AXI_04_BREADY                (AXI_04_BREADY      )
  ,.AXI_04_WDATA                 (AXI_04_WDATA       )
  ,.AXI_04_WLAST                 (AXI_04_WLAST       )
  ,.AXI_04_WSTRB                 (AXI_04_WSTRB       )
  ,.AXI_04_WDATA_PARITY          (AXI_04_WDATA_PARITY_i)
  ,.AXI_04_WVALID                (AXI_04_WVALID      )
  ,.AXI_05_ACLK                  (AXI_ACLK2_st0_buf     )
  ,.AXI_05_ARESET_N              (axi_rst2_st0_n        )
  ,.AXI_05_ARADDR                (AXI_05_ARADDR      )
  ,.AXI_05_ARBURST               (AXI_05_ARBURST     )
  ,.AXI_05_ARID                  (AXI_05_ARID        )
  ,.AXI_05_ARLEN                 (AXI_05_ARLEN[3:0]  )
  ,.AXI_05_ARSIZE                (AXI_05_ARSIZE      )
  ,.AXI_05_ARVALID               (AXI_05_ARVALID     )
  ,.AXI_05_AWADDR                (AXI_05_AWADDR      )
  ,.AXI_05_AWBURST               (AXI_05_AWBURST     )
  ,.AXI_05_AWID                  (AXI_05_AWID        )
  ,.AXI_05_AWLEN                 (AXI_05_AWLEN[3:0]  )
  ,.AXI_05_AWSIZE                (AXI_05_AWSIZE      )
  ,.AXI_05_AWVALID               (AXI_05_AWVALID     )
  ,.AXI_05_RREADY                (AXI_05_RREADY      )
  ,.AXI_05_BREADY                (AXI_05_BREADY      )
  ,.AXI_05_WDATA                 (AXI_05_WDATA       )
  ,.AXI_05_WLAST                 (AXI_05_WLAST       )
  ,.AXI_05_WSTRB                 (AXI_05_WSTRB       )
  ,.AXI_05_WDATA_PARITY          (AXI_05_WDATA_PARITY_i)
  ,.AXI_05_WVALID                (AXI_05_WVALID      )
  ,.AXI_06_ACLK                  (AXI_ACLK3_st0_buf     )
  ,.AXI_06_ARESET_N              (axi_rst3_st0_n        )
  ,.AXI_06_ARADDR                (AXI_06_ARADDR      )
  ,.AXI_06_ARBURST               (AXI_06_ARBURST     )
  ,.AXI_06_ARID                  (AXI_06_ARID        )
  ,.AXI_06_ARLEN                 (AXI_06_ARLEN[3:0]  )
  ,.AXI_06_ARSIZE                (AXI_06_ARSIZE      )
  ,.AXI_06_ARVALID               (AXI_06_ARVALID     )
  ,.AXI_06_AWADDR                (AXI_06_AWADDR      )
  ,.AXI_06_AWBURST               (AXI_06_AWBURST     )
  ,.AXI_06_AWID                  (AXI_06_AWID        )
  ,.AXI_06_AWLEN                 (AXI_06_AWLEN[3:0]  )
  ,.AXI_06_AWSIZE                (AXI_06_AWSIZE      )
  ,.AXI_06_AWVALID               (AXI_06_AWVALID     )
  ,.AXI_06_RREADY                (AXI_06_RREADY      )
  ,.AXI_06_BREADY                (AXI_06_BREADY      )
  ,.AXI_06_WDATA                 (AXI_06_WDATA       )
  ,.AXI_06_WLAST                 (AXI_06_WLAST       )
  ,.AXI_06_WSTRB                 (AXI_06_WSTRB       )
  ,.AXI_06_WDATA_PARITY          (AXI_06_WDATA_PARITY_i)
  ,.AXI_06_WVALID                (AXI_06_WVALID      )
  ,.AXI_07_ACLK                  (AXI_ACLK3_st0_buf     )
  ,.AXI_07_ARESET_N              (axi_rst3_st0_n        )
  ,.AXI_07_ARADDR                (AXI_07_ARADDR      )
  ,.AXI_07_ARBURST               (AXI_07_ARBURST     )
  ,.AXI_07_ARID                  (AXI_07_ARID        )
  ,.AXI_07_ARLEN                 (AXI_07_ARLEN[3:0]  )
  ,.AXI_07_ARSIZE                (AXI_07_ARSIZE      )
  ,.AXI_07_ARVALID               (AXI_07_ARVALID     )
  ,.AXI_07_AWADDR                (AXI_07_AWADDR      )
  ,.AXI_07_AWBURST               (AXI_07_AWBURST     )
  ,.AXI_07_AWID                  (AXI_07_AWID        )
  ,.AXI_07_AWLEN                 (AXI_07_AWLEN[3:0]  )
  ,.AXI_07_AWSIZE                (AXI_07_AWSIZE      )
  ,.AXI_07_AWVALID               (AXI_07_AWVALID     )
  ,.AXI_07_RREADY                (AXI_07_RREADY      )
  ,.AXI_07_BREADY                (AXI_07_BREADY      )
  ,.AXI_07_WDATA                 (AXI_07_WDATA       )
  ,.AXI_07_WLAST                 (AXI_07_WLAST       )
  ,.AXI_07_WSTRB                 (AXI_07_WSTRB       )
  ,.AXI_07_WDATA_PARITY          (AXI_07_WDATA_PARITY_i)
  ,.AXI_07_WVALID                (AXI_07_WVALID      )
  ,.AXI_08_ACLK                  (AXI_ACLK4_st0_buf     )
  ,.AXI_08_ARESET_N              (axi_rst4_st0_n        )
  ,.AXI_08_ARADDR                (AXI_08_ARADDR      )
  ,.AXI_08_ARBURST               (AXI_08_ARBURST     )
  ,.AXI_08_ARID                  (AXI_08_ARID        )
  ,.AXI_08_ARLEN                 (AXI_08_ARLEN[3:0]  )
  ,.AXI_08_ARSIZE                (AXI_08_ARSIZE      )
  ,.AXI_08_ARVALID               (AXI_08_ARVALID     )
  ,.AXI_08_AWADDR                (AXI_08_AWADDR      )
  ,.AXI_08_AWBURST               (AXI_08_AWBURST     )
  ,.AXI_08_AWID                  (AXI_08_AWID        )
  ,.AXI_08_AWLEN                 (AXI_08_AWLEN[3:0]  )
  ,.AXI_08_AWSIZE                (AXI_08_AWSIZE      )
  ,.AXI_08_AWVALID               (AXI_08_AWVALID     )
  ,.AXI_08_RREADY                (AXI_08_RREADY      )
  ,.AXI_08_BREADY                (AXI_08_BREADY      )
  ,.AXI_08_WDATA                 (AXI_08_WDATA       )
  ,.AXI_08_WLAST                 (AXI_08_WLAST       )
  ,.AXI_08_WSTRB                 (AXI_08_WSTRB       )
  ,.AXI_08_WDATA_PARITY          (AXI_08_WDATA_PARITY_i)
  ,.AXI_08_WVALID                (AXI_08_WVALID      )
  ,.AXI_09_ACLK                  (AXI_ACLK4_st0_buf     )
  ,.AXI_09_ARESET_N              (axi_rst4_st0_n        )
  ,.AXI_09_ARADDR                (AXI_09_ARADDR      )
  ,.AXI_09_ARBURST               (AXI_09_ARBURST     )
  ,.AXI_09_ARID                  (AXI_09_ARID        )
  ,.AXI_09_ARLEN                 (AXI_09_ARLEN[3:0]  )
  ,.AXI_09_ARSIZE                (AXI_09_ARSIZE      )
  ,.AXI_09_ARVALID               (AXI_09_ARVALID     )
  ,.AXI_09_AWADDR                (AXI_09_AWADDR      )
  ,.AXI_09_AWBURST               (AXI_09_AWBURST     )
  ,.AXI_09_AWID                  (AXI_09_AWID        )
  ,.AXI_09_AWLEN                 (AXI_09_AWLEN[3:0]  )
  ,.AXI_09_AWSIZE                (AXI_09_AWSIZE      )
  ,.AXI_09_AWVALID               (AXI_09_AWVALID     )
  ,.AXI_09_RREADY                (AXI_09_RREADY      )
  ,.AXI_09_BREADY                (AXI_09_BREADY      )
  ,.AXI_09_WDATA                 (AXI_09_WDATA       )
  ,.AXI_09_WLAST                 (AXI_09_WLAST       )
  ,.AXI_09_WSTRB                 (AXI_09_WSTRB       )
  ,.AXI_09_WDATA_PARITY          (AXI_09_WDATA_PARITY_i)
  ,.AXI_09_WVALID                (AXI_09_WVALID      )
  ,.AXI_10_ACLK                  (AXI_ACLK5_st0_buf     )
  ,.AXI_10_ARESET_N              (axi_rst5_st0_n        )
  ,.AXI_10_ARADDR                (AXI_10_ARADDR      )
  ,.AXI_10_ARBURST               (AXI_10_ARBURST     )
  ,.AXI_10_ARID                  (AXI_10_ARID        )
  ,.AXI_10_ARLEN                 (AXI_10_ARLEN[3:0]  )
  ,.AXI_10_ARSIZE                (AXI_10_ARSIZE      )
  ,.AXI_10_ARVALID               (AXI_10_ARVALID     )
  ,.AXI_10_AWADDR                (AXI_10_AWADDR      )
  ,.AXI_10_AWBURST               (AXI_10_AWBURST     )
  ,.AXI_10_AWID                  (AXI_10_AWID        )
  ,.AXI_10_AWLEN                 (AXI_10_AWLEN[3:0]  )
  ,.AXI_10_AWSIZE                (AXI_10_AWSIZE      )
  ,.AXI_10_AWVALID               (AXI_10_AWVALID     )
  ,.AXI_10_RREADY                (AXI_10_RREADY      )
  ,.AXI_10_BREADY                (AXI_10_BREADY      )
  ,.AXI_10_WDATA                 (AXI_10_WDATA       )
  ,.AXI_10_WLAST                 (AXI_10_WLAST       )
  ,.AXI_10_WSTRB                 (AXI_10_WSTRB       )
  ,.AXI_10_WDATA_PARITY          (AXI_10_WDATA_PARITY_i)
  ,.AXI_10_WVALID                (AXI_10_WVALID      )
  ,.AXI_11_ACLK                  (AXI_ACLK5_st0_buf     )
  ,.AXI_11_ARESET_N              (axi_rst5_st0_n        )
  ,.AXI_11_ARADDR                (AXI_11_ARADDR      )
  ,.AXI_11_ARBURST               (AXI_11_ARBURST     )
  ,.AXI_11_ARID                  (AXI_11_ARID        )
  ,.AXI_11_ARLEN                 (AXI_11_ARLEN[3:0]  )
  ,.AXI_11_ARSIZE                (AXI_11_ARSIZE      )
  ,.AXI_11_ARVALID               (AXI_11_ARVALID     )
  ,.AXI_11_AWADDR                (AXI_11_AWADDR      )
  ,.AXI_11_AWBURST               (AXI_11_AWBURST     )
  ,.AXI_11_AWID                  (AXI_11_AWID        )
  ,.AXI_11_AWLEN                 (AXI_11_AWLEN[3:0]  )
  ,.AXI_11_AWSIZE                (AXI_11_AWSIZE      )
  ,.AXI_11_AWVALID               (AXI_11_AWVALID     )
  ,.AXI_11_RREADY                (AXI_11_RREADY      )
  ,.AXI_11_BREADY                (AXI_11_BREADY      )
  ,.AXI_11_WDATA                 (AXI_11_WDATA       )
  ,.AXI_11_WLAST                 (AXI_11_WLAST       )
  ,.AXI_11_WSTRB                 (AXI_11_WSTRB       )
  ,.AXI_11_WDATA_PARITY          (AXI_11_WDATA_PARITY_i)
  ,.AXI_11_WVALID                (AXI_11_WVALID      )
  ,.AXI_12_ACLK                  (AXI_ACLK5_st0_buf     )
  ,.AXI_12_ARESET_N              (axi_rst5_st0_n        )
  ,.AXI_12_ARADDR                (AXI_12_ARADDR      )
  ,.AXI_12_ARBURST               (AXI_12_ARBURST     )
  ,.AXI_12_ARID                  (AXI_12_ARID        )
  ,.AXI_12_ARLEN                 (AXI_12_ARLEN[3:0]  )
  ,.AXI_12_ARSIZE                (AXI_12_ARSIZE      )
  ,.AXI_12_ARVALID               (AXI_12_ARVALID     )
  ,.AXI_12_AWADDR                (AXI_12_AWADDR      )
  ,.AXI_12_AWBURST               (AXI_12_AWBURST     )
  ,.AXI_12_AWID                  (AXI_12_AWID        )
  ,.AXI_12_AWLEN                 (AXI_12_AWLEN[3:0]  )
  ,.AXI_12_AWSIZE                (AXI_12_AWSIZE      )
  ,.AXI_12_AWVALID               (AXI_12_AWVALID     )
  ,.AXI_12_RREADY                (AXI_12_RREADY      )
  ,.AXI_12_BREADY                (AXI_12_BREADY      )
  ,.AXI_12_WDATA                 (AXI_12_WDATA       )
  ,.AXI_12_WLAST                 (AXI_12_WLAST       )
  ,.AXI_12_WSTRB                 (AXI_12_WSTRB       )
  ,.AXI_12_WDATA_PARITY          (AXI_12_WDATA_PARITY_i)
  ,.AXI_12_WVALID                (AXI_12_WVALID      )
  ,.AXI_13_ACLK                  (AXI_ACLK6_st0_buf     )
  ,.AXI_13_ARESET_N              (axi_rst6_st0_n        )
  ,.AXI_13_ARADDR                (AXI_13_ARADDR      )
  ,.AXI_13_ARBURST               (AXI_13_ARBURST     )
  ,.AXI_13_ARID                  (AXI_13_ARID        )
  ,.AXI_13_ARLEN                 (AXI_13_ARLEN[3:0]  )
  ,.AXI_13_ARSIZE                (AXI_13_ARSIZE      )
  ,.AXI_13_ARVALID               (AXI_13_ARVALID     )
  ,.AXI_13_AWADDR                (AXI_13_AWADDR      )
  ,.AXI_13_AWBURST               (AXI_13_AWBURST     )
  ,.AXI_13_AWID                  (AXI_13_AWID        )
  ,.AXI_13_AWLEN                 (AXI_13_AWLEN[3:0]  )
  ,.AXI_13_AWSIZE                (AXI_13_AWSIZE      )
  ,.AXI_13_AWVALID               (AXI_13_AWVALID     )
  ,.AXI_13_RREADY                (AXI_13_RREADY      )
  ,.AXI_13_BREADY                (AXI_13_BREADY      )
  ,.AXI_13_WDATA                 (AXI_13_WDATA       )
  ,.AXI_13_WLAST                 (AXI_13_WLAST       )
  ,.AXI_13_WSTRB                 (AXI_13_WSTRB       )
  ,.AXI_13_WDATA_PARITY          (AXI_13_WDATA_PARITY_i)
  ,.AXI_13_WVALID                (AXI_13_WVALID      )
  ,.AXI_14_ACLK                  (AXI_ACLK6_st0_buf     )
  ,.AXI_14_ARESET_N              (axi_rst6_st0_n        )
  ,.AXI_14_ARADDR                (AXI_14_ARADDR      )
  ,.AXI_14_ARBURST               (AXI_14_ARBURST     )
  ,.AXI_14_ARID                  (AXI_14_ARID        )
  ,.AXI_14_ARLEN                 (AXI_14_ARLEN[3:0]  )
  ,.AXI_14_ARSIZE                (AXI_14_ARSIZE      )
  ,.AXI_14_ARVALID               (AXI_14_ARVALID     )
  ,.AXI_14_AWADDR                (AXI_14_AWADDR      )
  ,.AXI_14_AWBURST               (AXI_14_AWBURST     )
  ,.AXI_14_AWID                  (AXI_14_AWID        )
  ,.AXI_14_AWLEN                 (AXI_14_AWLEN[3:0]  )
  ,.AXI_14_AWSIZE                (AXI_14_AWSIZE      )
  ,.AXI_14_AWVALID               (AXI_14_AWVALID     )
  ,.AXI_14_RREADY                (AXI_14_RREADY      )
  ,.AXI_14_BREADY                (AXI_14_BREADY      )
  ,.AXI_14_WDATA                 (AXI_14_WDATA       )
  ,.AXI_14_WLAST                 (AXI_14_WLAST       )
  ,.AXI_14_WSTRB                 (AXI_14_WSTRB       )
  ,.AXI_14_WDATA_PARITY          (AXI_14_WDATA_PARITY_i)
  ,.AXI_14_WVALID                (AXI_14_WVALID      )
  ,.AXI_15_ACLK                  (AXI_ACLK6_st0_buf     )
  ,.AXI_15_ARESET_N              (axi_rst6_st0_n        )
  ,.AXI_15_ARADDR                (AXI_15_ARADDR      )
  ,.AXI_15_ARBURST               (AXI_15_ARBURST     )
  ,.AXI_15_ARID                  (AXI_15_ARID        )
  ,.AXI_15_ARLEN                 (AXI_15_ARLEN[3:0]  )
  ,.AXI_15_ARSIZE                (AXI_15_ARSIZE      )
  ,.AXI_15_ARVALID               (AXI_15_ARVALID     )
  ,.AXI_15_AWADDR                (AXI_15_AWADDR      )
  ,.AXI_15_AWBURST               (AXI_15_AWBURST     )
  ,.AXI_15_AWID                  (AXI_15_AWID        )
  ,.AXI_15_AWLEN                 (AXI_15_AWLEN[3:0]  )
  ,.AXI_15_AWSIZE                (AXI_15_AWSIZE      )
  ,.AXI_15_AWVALID               (AXI_15_AWVALID     )
  ,.AXI_15_RREADY                (AXI_15_RREADY      )
  ,.AXI_15_BREADY                (AXI_15_BREADY      )
  ,.AXI_15_WDATA                 (AXI_15_WDATA       )
  ,.AXI_15_WLAST                 (AXI_15_WLAST       )
  ,.AXI_15_WSTRB                 (AXI_15_WSTRB       )
  ,.AXI_15_WDATA_PARITY          (AXI_15_WDATA_PARITY_i)
  ,.AXI_15_WVALID                (AXI_15_WVALID      )

  ,.APB_0_PWDATA                 (APB_0_PWDATA  )
  ,.APB_0_PADDR                  (APB_0_PADDR   )
  ,.APB_0_PCLK                   (APB_0_PCLK_BUF)
  ,.APB_0_PENABLE                (APB_0_PENABLE )
  ,.APB_0_PRESET_N               (APB_0_PRESET_N)
  ,.APB_0_PSEL                   (APB_0_PSEL    )
  ,.APB_0_PWRITE                 (APB_0_PWRITE  )
  ,.AXI_00_ARREADY               (AXI_00_ARREADY     )
  ,.AXI_00_AWREADY               (AXI_00_AWREADY     )
  ,.AXI_00_RDATA_PARITY          (AXI_00_RDATA_PARITY)
  ,.AXI_00_RDATA                 (AXI_00_RDATA       )
  ,.AXI_00_RID                   (AXI_00_RID         )
  ,.AXI_00_RLAST                 (AXI_00_RLAST       )
  ,.AXI_00_RRESP                 (AXI_00_RRESP       )
  ,.AXI_00_RVALID                (AXI_00_RVALID      )
  ,.AXI_00_WREADY                (AXI_00_WREADY      )
  ,.AXI_00_BID                   (AXI_00_BID         )
  ,.AXI_00_BRESP                 (AXI_00_BRESP       )
  ,.AXI_00_BVALID                (AXI_00_BVALID      )
  ,.AXI_01_ARREADY               (AXI_01_ARREADY     )
  ,.AXI_01_AWREADY               (AXI_01_AWREADY     )
  ,.AXI_01_RDATA_PARITY          (AXI_01_RDATA_PARITY)
  ,.AXI_01_RDATA                 (AXI_01_RDATA       )
  ,.AXI_01_RID                   (AXI_01_RID         )
  ,.AXI_01_RLAST                 (AXI_01_RLAST       )
  ,.AXI_01_RRESP                 (AXI_01_RRESP       )
  ,.AXI_01_RVALID                (AXI_01_RVALID      )
  ,.AXI_01_WREADY                (AXI_01_WREADY      )
  ,.AXI_01_BID                   (AXI_01_BID         )
  ,.AXI_01_BRESP                 (AXI_01_BRESP       )
  ,.AXI_01_BVALID                (AXI_01_BVALID      )
  ,.AXI_02_ARREADY               (AXI_02_ARREADY     )
  ,.AXI_02_AWREADY               (AXI_02_AWREADY     )
  ,.AXI_02_RDATA_PARITY          (AXI_02_RDATA_PARITY)
  ,.AXI_02_RDATA                 (AXI_02_RDATA       )
  ,.AXI_02_RID                   (AXI_02_RID         )
  ,.AXI_02_RLAST                 (AXI_02_RLAST       )
  ,.AXI_02_RRESP                 (AXI_02_RRESP       )
  ,.AXI_02_RVALID                (AXI_02_RVALID      )
  ,.AXI_02_WREADY                (AXI_02_WREADY      )
  ,.AXI_02_BID                   (AXI_02_BID         )
  ,.AXI_02_BRESP                 (AXI_02_BRESP       )
  ,.AXI_02_BVALID                (AXI_02_BVALID      )
  ,.AXI_03_ARREADY               (AXI_03_ARREADY     )
  ,.AXI_03_AWREADY               (AXI_03_AWREADY     )
  ,.AXI_03_RDATA_PARITY          (AXI_03_RDATA_PARITY)
  ,.AXI_03_RDATA                 (AXI_03_RDATA       )
  ,.AXI_03_RID                   (AXI_03_RID         )
  ,.AXI_03_RLAST                 (AXI_03_RLAST       )
  ,.AXI_03_RRESP                 (AXI_03_RRESP       )
  ,.AXI_03_RVALID                (AXI_03_RVALID      )
  ,.AXI_03_WREADY                (AXI_03_WREADY      )
  ,.AXI_03_BID                   (AXI_03_BID         )
  ,.AXI_03_BRESP                 (AXI_03_BRESP       )
  ,.AXI_03_BVALID                (AXI_03_BVALID      )
  ,.AXI_04_ARREADY               (AXI_04_ARREADY     )
  ,.AXI_04_AWREADY               (AXI_04_AWREADY     )
  ,.AXI_04_RDATA_PARITY          (AXI_04_RDATA_PARITY)
  ,.AXI_04_RDATA                 (AXI_04_RDATA       )
  ,.AXI_04_RID                   (AXI_04_RID         )
  ,.AXI_04_RLAST                 (AXI_04_RLAST       )
  ,.AXI_04_RRESP                 (AXI_04_RRESP       )
  ,.AXI_04_RVALID                (AXI_04_RVALID      )
  ,.AXI_04_WREADY                (AXI_04_WREADY      )
  ,.AXI_04_BID                   (AXI_04_BID         )
  ,.AXI_04_BRESP                 (AXI_04_BRESP       )
  ,.AXI_04_BVALID                (AXI_04_BVALID      )
  ,.AXI_05_ARREADY               (AXI_05_ARREADY     )
  ,.AXI_05_AWREADY               (AXI_05_AWREADY     )
  ,.AXI_05_RDATA_PARITY          (AXI_05_RDATA_PARITY)
  ,.AXI_05_RDATA                 (AXI_05_RDATA       )
  ,.AXI_05_RID                   (AXI_05_RID         )
  ,.AXI_05_RLAST                 (AXI_05_RLAST       )
  ,.AXI_05_RRESP                 (AXI_05_RRESP       )
  ,.AXI_05_RVALID                (AXI_05_RVALID      )
  ,.AXI_05_WREADY                (AXI_05_WREADY      )
  ,.AXI_05_BID                   (AXI_05_BID         )
  ,.AXI_05_BRESP                 (AXI_05_BRESP       )
  ,.AXI_05_BVALID                (AXI_05_BVALID      )
  ,.AXI_06_ARREADY               (AXI_06_ARREADY     )
  ,.AXI_06_AWREADY               (AXI_06_AWREADY     )
  ,.AXI_06_RDATA_PARITY          (AXI_06_RDATA_PARITY)
  ,.AXI_06_RDATA                 (AXI_06_RDATA       )
  ,.AXI_06_RID                   (AXI_06_RID         )
  ,.AXI_06_RLAST                 (AXI_06_RLAST       )
  ,.AXI_06_RRESP                 (AXI_06_RRESP       )
  ,.AXI_06_RVALID                (AXI_06_RVALID      )
  ,.AXI_06_WREADY                (AXI_06_WREADY      )
  ,.AXI_06_BID                   (AXI_06_BID         )
  ,.AXI_06_BRESP                 (AXI_06_BRESP       )
  ,.AXI_06_BVALID                (AXI_06_BVALID      )
  ,.AXI_07_ARREADY               (AXI_07_ARREADY     )
  ,.AXI_07_AWREADY               (AXI_07_AWREADY     )
  ,.AXI_07_RDATA_PARITY          (AXI_07_RDATA_PARITY)
  ,.AXI_07_RDATA                 (AXI_07_RDATA       )
  ,.AXI_07_RID                   (AXI_07_RID         )
  ,.AXI_07_RLAST                 (AXI_07_RLAST       )
  ,.AXI_07_RRESP                 (AXI_07_RRESP       )
  ,.AXI_07_RVALID                (AXI_07_RVALID      )
  ,.AXI_07_WREADY                (AXI_07_WREADY      )
  ,.AXI_07_BID                   (AXI_07_BID         )
  ,.AXI_07_BRESP                 (AXI_07_BRESP       )
  ,.AXI_07_BVALID                (AXI_07_BVALID      )
  ,.AXI_08_ARREADY               (AXI_08_ARREADY     )
  ,.AXI_08_AWREADY               (AXI_08_AWREADY     )
  ,.AXI_08_RDATA_PARITY          (AXI_08_RDATA_PARITY)
  ,.AXI_08_RDATA                 (AXI_08_RDATA       )
  ,.AXI_08_RID                   (AXI_08_RID         )
  ,.AXI_08_RLAST                 (AXI_08_RLAST       )
  ,.AXI_08_RRESP                 (AXI_08_RRESP       )
  ,.AXI_08_RVALID                (AXI_08_RVALID      )
  ,.AXI_08_WREADY                (AXI_08_WREADY      )
  ,.AXI_08_BID                   (AXI_08_BID         )
  ,.AXI_08_BRESP                 (AXI_08_BRESP       )
  ,.AXI_08_BVALID                (AXI_08_BVALID      )
  ,.AXI_09_ARREADY               (AXI_09_ARREADY     )
  ,.AXI_09_AWREADY               (AXI_09_AWREADY     )
  ,.AXI_09_RDATA_PARITY          (AXI_09_RDATA_PARITY)
  ,.AXI_09_RDATA                 (AXI_09_RDATA       )
  ,.AXI_09_RID                   (AXI_09_RID         )
  ,.AXI_09_RLAST                 (AXI_09_RLAST       )
  ,.AXI_09_RRESP                 (AXI_09_RRESP       )
  ,.AXI_09_RVALID                (AXI_09_RVALID      )
  ,.AXI_09_WREADY                (AXI_09_WREADY      )
  ,.AXI_09_BID                   (AXI_09_BID         )
  ,.AXI_09_BRESP                 (AXI_09_BRESP       )
  ,.AXI_09_BVALID                (AXI_09_BVALID      )
  ,.AXI_10_ARREADY               (AXI_10_ARREADY     )
  ,.AXI_10_AWREADY               (AXI_10_AWREADY     )
  ,.AXI_10_RDATA_PARITY          (AXI_10_RDATA_PARITY)
  ,.AXI_10_RDATA                 (AXI_10_RDATA       )
  ,.AXI_10_RID                   (AXI_10_RID         )
  ,.AXI_10_RLAST                 (AXI_10_RLAST       )
  ,.AXI_10_RRESP                 (AXI_10_RRESP       )
  ,.AXI_10_RVALID                (AXI_10_RVALID      )
  ,.AXI_10_WREADY                (AXI_10_WREADY      )
  ,.AXI_10_BID                   (AXI_10_BID         )
  ,.AXI_10_BRESP                 (AXI_10_BRESP       )
  ,.AXI_10_BVALID                (AXI_10_BVALID      )
  ,.AXI_11_ARREADY               (AXI_11_ARREADY     )
  ,.AXI_11_AWREADY               (AXI_11_AWREADY     )
  ,.AXI_11_RDATA_PARITY          (AXI_11_RDATA_PARITY)
  ,.AXI_11_RDATA                 (AXI_11_RDATA       )
  ,.AXI_11_RID                   (AXI_11_RID         )
  ,.AXI_11_RLAST                 (AXI_11_RLAST       )
  ,.AXI_11_RRESP                 (AXI_11_RRESP       )
  ,.AXI_11_RVALID                (AXI_11_RVALID      )
  ,.AXI_11_WREADY                (AXI_11_WREADY      )
  ,.AXI_11_BID                   (AXI_11_BID         )
  ,.AXI_11_BRESP                 (AXI_11_BRESP       )
  ,.AXI_11_BVALID                (AXI_11_BVALID      )
  ,.AXI_12_ARREADY               (AXI_12_ARREADY     )
  ,.AXI_12_AWREADY               (AXI_12_AWREADY     )
  ,.AXI_12_RDATA_PARITY          (AXI_12_RDATA_PARITY)
  ,.AXI_12_RDATA                 (AXI_12_RDATA       )
  ,.AXI_12_RID                   (AXI_12_RID         )
  ,.AXI_12_RLAST                 (AXI_12_RLAST       )
  ,.AXI_12_RRESP                 (AXI_12_RRESP       )
  ,.AXI_12_RVALID                (AXI_12_RVALID      )
  ,.AXI_12_WREADY                (AXI_12_WREADY      )
  ,.AXI_12_BID                   (AXI_12_BID         )
  ,.AXI_12_BRESP                 (AXI_12_BRESP       )
  ,.AXI_12_BVALID                (AXI_12_BVALID      )
  ,.AXI_13_ARREADY               (AXI_13_ARREADY     )
  ,.AXI_13_AWREADY               (AXI_13_AWREADY     )
  ,.AXI_13_RDATA_PARITY          (AXI_13_RDATA_PARITY)
  ,.AXI_13_RDATA                 (AXI_13_RDATA       )
  ,.AXI_13_RID                   (AXI_13_RID         )
  ,.AXI_13_RLAST                 (AXI_13_RLAST       )
  ,.AXI_13_RRESP                 (AXI_13_RRESP       )
  ,.AXI_13_RVALID                (AXI_13_RVALID      )
  ,.AXI_13_WREADY                (AXI_13_WREADY      )
  ,.AXI_13_BID                   (AXI_13_BID         )
  ,.AXI_13_BRESP                 (AXI_13_BRESP       )
  ,.AXI_13_BVALID                (AXI_13_BVALID      )
  ,.AXI_14_ARREADY               (AXI_14_ARREADY     )
  ,.AXI_14_AWREADY               (AXI_14_AWREADY     )
  ,.AXI_14_RDATA_PARITY          (AXI_14_RDATA_PARITY)
  ,.AXI_14_RDATA                 (AXI_14_RDATA       )
  ,.AXI_14_RID                   (AXI_14_RID         )
  ,.AXI_14_RLAST                 (AXI_14_RLAST       )
  ,.AXI_14_RRESP                 (AXI_14_RRESP       )
  ,.AXI_14_RVALID                (AXI_14_RVALID      )
  ,.AXI_14_WREADY                (AXI_14_WREADY      )
  ,.AXI_14_BID                   (AXI_14_BID         )
  ,.AXI_14_BRESP                 (AXI_14_BRESP       )
  ,.AXI_14_BVALID                (AXI_14_BVALID      )
  ,.AXI_15_ARREADY               (AXI_15_ARREADY     )
  ,.AXI_15_AWREADY               (AXI_15_AWREADY     )
  ,.AXI_15_RDATA_PARITY          (AXI_15_RDATA_PARITY)
  ,.AXI_15_RDATA                 (AXI_15_RDATA       )
  ,.AXI_15_RID                   (AXI_15_RID         )
  ,.AXI_15_RLAST                 (AXI_15_RLAST       )
  ,.AXI_15_RRESP                 (AXI_15_RRESP       )
  ,.AXI_15_RVALID                (AXI_15_RVALID      )
  ,.AXI_15_WREADY                (AXI_15_WREADY      )
  ,.AXI_15_BID                   (AXI_15_BID         )
  ,.AXI_15_BRESP                 (AXI_15_BRESP       )
  ,.AXI_15_BVALID                (AXI_15_BVALID      )
  ,.apb_complete_0               (apb_seq_complete_0_s)
  ,.APB_0_PRDATA                 (APB_0_PRDATA )
  ,.APB_0_PREADY                 (APB_0_PREADY )
  ,.APB_0_PSLVERR                (APB_0_PSLVERR)

  ,.DRAM_0_STAT_CATTRIP          (DRAM_0_STAT_CATTRIP)
  ,.DRAM_0_STAT_TEMP             (DRAM_0_STAT_TEMP   )
);


always @ (posedge AXI_ACLK0_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_0_st0_r0 <= 1'b0;
    apb_seq_complete_0_st0_r1 <= 1'b0;
    apb_seq_complete_0_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_0_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_0_st0_r1 <= apb_seq_complete_0_st0_r0;
    apb_seq_complete_0_st0_r2 <= apb_seq_complete_0_st0_r1;
  end
end

assign tg_start_st0_0 = apb_seq_complete_0_st0_r1 && ~(apb_seq_complete_0_st0_r2);

always @ (posedge AXI_ACLK1_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_1_st0_r0 <= 1'b0;
    apb_seq_complete_1_st0_r1 <= 1'b0;
    apb_seq_complete_1_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_1_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_1_st0_r1 <= apb_seq_complete_1_st0_r0;
    apb_seq_complete_1_st0_r2 <= apb_seq_complete_1_st0_r1;
  end
end

assign tg_start_st0_1 = apb_seq_complete_1_st0_r1 && ~(apb_seq_complete_1_st0_r2);

always @ (posedge AXI_ACLK2_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_2_st0_r0 <= 1'b0;
    apb_seq_complete_2_st0_r1 <= 1'b0;
    apb_seq_complete_2_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_2_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_2_st0_r1 <= apb_seq_complete_2_st0_r0;
    apb_seq_complete_2_st0_r2 <= apb_seq_complete_2_st0_r1;
  end
end

assign tg_start_st0_2 = apb_seq_complete_2_st0_r1 && ~(apb_seq_complete_2_st0_r2);

always @ (posedge AXI_ACLK3_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_3_st0_r0 <= 1'b0;
    apb_seq_complete_3_st0_r1 <= 1'b0;
    apb_seq_complete_3_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_3_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_3_st0_r1 <= apb_seq_complete_3_st0_r0;
    apb_seq_complete_3_st0_r2 <= apb_seq_complete_3_st0_r1;
  end
end

assign tg_start_st0_3 = apb_seq_complete_3_st0_r1 && ~(apb_seq_complete_3_st0_r2);

always @ (posedge AXI_ACLK4_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_4_st0_r0 <= 1'b0;
    apb_seq_complete_4_st0_r1 <= 1'b0;
    apb_seq_complete_4_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_4_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_4_st0_r1 <= apb_seq_complete_4_st0_r0;
    apb_seq_complete_4_st0_r2 <= apb_seq_complete_4_st0_r1;
  end
end

assign tg_start_st0_4 = apb_seq_complete_4_st0_r1 && ~(apb_seq_complete_4_st0_r2);

always @ (posedge AXI_ACLK5_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_5_st0_r0 <= 1'b0;
    apb_seq_complete_5_st0_r1 <= 1'b0;
    apb_seq_complete_5_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_5_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_5_st0_r1 <= apb_seq_complete_5_st0_r0;
    apb_seq_complete_5_st0_r2 <= apb_seq_complete_5_st0_r1;
  end
end

assign tg_start_st0_5 = apb_seq_complete_5_st0_r1 && ~(apb_seq_complete_5_st0_r2);

always @ (posedge AXI_ACLK6_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_6_st0_r0 <= 1'b0;
    apb_seq_complete_6_st0_r1 <= 1'b0;
    apb_seq_complete_6_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_6_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_6_st0_r1 <= apb_seq_complete_6_st0_r0;
    apb_seq_complete_6_st0_r2 <= apb_seq_complete_6_st0_r1;
  end
end

assign tg_start_st0_6 = apb_seq_complete_6_st0_r1 && ~(apb_seq_complete_6_st0_r2);


////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 0
////////////////////////////////////////////////////////////////////////////////
// assign AXI_00_ARADDR = {vio_tg_glb_start_addr_0[32:28],o_m_axi_araddr_0[27:0]};
// assign AXI_00_AWADDR = {vio_tg_glb_start_addr_0[32:28],o_m_axi_awaddr_0[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_0 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK0_st0_buf),
  .i_rst                               (~axi_rst0_st0_n),
  .i_init_calib_complete               (apb_seq_complete_0_st0_r2),
  .compare_error                       (axi_00_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_0),
  .vio_tg_start                        (vio_tg_start_0),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_0),
  .vio_tg_err_clear                    (vio_tg_err_clear_0),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_0),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_0),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_0),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_0),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_0),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_0),
  .vio_tg_restart                      (vio_tg_restart_0),
  .vio_tg_pause                        (vio_tg_pause_0),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_0),
  .vio_tg_err_continue                 (vio_tg_err_continue_0),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_0),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_0),
  .vio_tg_instr_num                    (vio_tg_instr_num_0),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_0),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_0),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_0),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_0),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_0),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_0),
  .vio_tg_seed_num                     (vio_tg_seed_num_0),
  .vio_tg_seed                         (vio_tg_seed_0),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_0),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_0),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_0),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_0),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_0),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_0),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_0),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_0),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_0),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_0),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_0),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_0),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_0),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_0),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_0),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_0),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_0),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_0),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_0),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_0),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_0),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_0),
  .vio_tg_status_err_type              (vio_tg_status_err_type_0),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_0),
  .vio_tg_status_done                  (boot_mode_done_0),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_0),
  .tg_ila_debug                        (tg_ila_debug_0),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_00_AWID    = axi4_hbm_chs_li[0].awid;
  assign AXI_00_AWADDR  = axi4_hbm_chs_li[0].awaddr[0][32:0];
  assign AXI_00_AWLEN   = axi4_hbm_chs_li[0].awlen;
  assign AXI_00_AWSIZE  = axi4_hbm_chs_li[0].awsize;
  assign AXI_00_AWBURST = axi4_hbm_chs_li[0].awburst;
  // assign AXI_00_awlock = axi4_hbm_chs_li[0].awlock;
  assign AXI_00_AWCACHE = axi4_hbm_chs_li[0].awcache;
  assign AXI_00_AWPROT  = axi4_hbm_chs_li[0].awprot;
  assign AXI_00_AWVALID = axi4_hbm_chs_li[0].awvalid;
  assign AXI_00_WDATA   = axi4_hbm_chs_li[0].wdata;
  assign AXI_00_WSTRB   = axi4_hbm_chs_li[0].wstrb;
  assign AXI_00_WLAST   = axi4_hbm_chs_li[0].wlast;
  assign AXI_00_WVALID  = axi4_hbm_chs_li[0].wvalid;
  assign AXI_00_BREADY  = axi4_hbm_chs_li[0].bready;
  assign AXI_00_ARID    = axi4_hbm_chs_li[0].arid;
  assign AXI_00_ARADDR  = axi4_hbm_chs_li[0].araddr[0][32:0];
  assign AXI_00_ARLEN   = axi4_hbm_chs_li[0].arlen;
  assign AXI_00_ARSIZE  = axi4_hbm_chs_li[0].arsize;
  assign AXI_00_ARBURST = axi4_hbm_chs_li[0].arburst;
  // assign ( = axi4_hbm_chs_li[0].arburst;
  assign AXI_00_ARCACHE = axi4_hbm_chs_li[0].arcache;
  // assign ( = axi4_hbm_chs_li[0].arprot;
  assign AXI_00_ARVALID = axi4_hbm_chs_li[0].arvalid;
  assign AXI_00_RREADY  = axi4_hbm_chs_li[0].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[0].awready = AXI_00_AWREADY;
  assign axi4_hbm_chs_lo[0].wready  = AXI_00_WREADY;
  assign axi4_hbm_chs_lo[0].bid     = AXI_00_BID;
  assign axi4_hbm_chs_lo[0].bresp   = AXI_00_BRESP;
  assign axi4_hbm_chs_lo[0].bvalid  = AXI_00_BVALID;
  assign axi4_hbm_chs_lo[0].arready = AXI_00_ARREADY;
  assign axi4_hbm_chs_lo[0].rid     = AXI_00_RID;
  assign axi4_hbm_chs_lo[0].rresp   = AXI_00_RRESP;
  assign axi4_hbm_chs_lo[0].rvalid  = AXI_00_RVALID;
  assign axi4_hbm_chs_lo[0].rdata   = AXI_00_RDATA;
  assign axi4_hbm_chs_lo[0].rlast   = AXI_00_RLAST;


assign  vio_tg_rst_0 =  1'd0;
assign  i_force_vio_tg_status_done_0 = 16'h0000;
assign  i_vio_enable_atg_axi_x_0 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_0 =  16'hffff;
assign  vio_tg_restart_0 =  'd0;
assign  vio_tg_pause_0 =  'd0;
assign  vio_tg_err_chk_en_0 =  'd0;
assign  vio_tg_err_clear_0 =  'd0;
assign  vio_tg_err_clear_all_0 =  'd0;
assign  vio_tg_err_continue_0 =  'd0;
assign  vio_tg_instr_program_en_0 =  'd0;
assign  vio_tg_direct_instr_en_0 =  'd0;
assign  vio_tg_instr_num_0 =  'd0;
assign  vio_tg_instr_addr_mode_0 =  'd0;
assign  vio_tg_instr_data_mode_0 =  'd0;
assign  vio_tg_instr_rw_mode_0 =  'd0;
assign  vio_tg_instr_rw_submode_0 =  'd0;
assign  vio_tg_instr_victim_mode_0 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_0 =  'd0;
assign  vio_tg_instr_victim_select_0 =  'd0;
assign  vio_tg_instr_num_of_iter_0 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_0 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_0 =  'd0;
assign  vio_tg_instr_nxt_instr_0 =  'd0;
assign  vio_tg_seed_program_en_0 =  'd0;
assign  vio_tg_seed_num_0 =  'd0;
assign  vio_tg_seed_0 =  'd0;
assign  vio_tg_glb_victim_bit_0 =  'd0;
assign  vio_tg_glb_start_addr_0 = 33'h0_0000_0000;

always@(posedge AXI_ACLK0_st0_buf or negedge axi_rst0_st0_n) begin
  if (~axi_rst0_st0_n) begin
    rd_cnt_00 <= 5'b0;
  end else if (AXI_00_RVALID && AXI_00_RREADY) begin
    rd_cnt_00 <= rd_cnt_00 + 1'b1;
  end
end

always@(posedge AXI_ACLK0_st0_buf or negedge axi_rst0_st0_n) begin
  if (~axi_rst0_st0_n) begin
    wr_cnt_00 <= 5'b0;
  end else if (AXI_00_BVALID && AXI_00_BREADY) begin
    wr_cnt_00 <= wr_cnt_00 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 0
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (0)
) u_axi_pmon_0 (
  .axi_arst_n              (axi_rst0_st0_n    ),
  .axi_aclk                (AXI_ACLK0_st0_buf ),
  .axi_awid                (AXI_00_AWID),
  .axi_awaddr              (AXI_00_AWADDR),
  .axi_awlen               (AXI_00_AWLEN),
  .axi_awsize              (AXI_00_AWSIZE),
  .axi_awburst             (AXI_00_AWBURST),
  .axi_awcache             (AXI_00_AWCACHE),
  .axi_awprot              (AXI_00_AWPROT),
  .axi_awvalid             (AXI_00_AWVALID),
  .axi_awready             (AXI_00_AWREADY),
  .axi_wdata               (AXI_00_WDATA),
  .axi_wstrb               (AXI_00_WSTRB),
  .axi_wlast               (AXI_00_WLAST),
  .axi_wvalid              (AXI_00_WVALID),
  .axi_wready              (AXI_00_WREADY),
  .axi_bready              (AXI_00_BREADY),
  .axi_bid                 (AXI_00_BID),
  .axi_bresp               (AXI_00_BRESP),
  .axi_bvalid              (AXI_00_BVALID),
  .axi_arid                (AXI_00_ARID),
  .axi_araddr              (AXI_00_ARADDR),
  .axi_arlen               (AXI_00_ARLEN),
  .axi_arsize              (AXI_00_ARSIZE),
  .axi_arburst             (AXI_00_ARBURST),
  .axi_arcache             (AXI_00_ARCACHE),
  .axi_arvalid             (AXI_00_ARVALID),
  .axi_arready             (AXI_00_ARREADY),
  .axi_rready              (AXI_00_RREADY),
  .axi_rid                 (AXI_00_RID),
  .axi_rdata               (AXI_00_RDATA),
  .axi_rresp               (AXI_00_RRESP),
  .axi_rlast               (AXI_00_RLAST),
  .axi_rvalid              (AXI_00_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 1
////////////////////////////////////////////////////////////////////////////////
// assign AXI_01_ARADDR = {vio_tg_glb_start_addr_1[32:28],o_m_axi_araddr_1[27:0]};
// assign AXI_01_AWADDR = {vio_tg_glb_start_addr_1[32:28],o_m_axi_awaddr_1[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_1 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK0_st0_buf),
  .i_rst                               (~axi_rst0_st0_n),
  .i_init_calib_complete               (apb_seq_complete_0_st0_r2),
  .compare_error                       (axi_01_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_1),
  .vio_tg_start                        (vio_tg_start_1),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_1),
  .vio_tg_err_clear                    (vio_tg_err_clear_1),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_1),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_1),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_1),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_1),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_1),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_1),
  .vio_tg_restart                      (vio_tg_restart_1),
  .vio_tg_pause                        (vio_tg_pause_1),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_1),
  .vio_tg_err_continue                 (vio_tg_err_continue_1),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_1),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_1),
  .vio_tg_instr_num                    (vio_tg_instr_num_1),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_1),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_1),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_1),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_1),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_1),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_1),
  .vio_tg_seed_num                     (vio_tg_seed_num_1),
  .vio_tg_seed                         (vio_tg_seed_1),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_1),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_1),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_1),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_1),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_1),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_1),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_1),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_1),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_1),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_1),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_1),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_1),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_1),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_1),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_1),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_1),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_1),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_1),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_1),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_1),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_1),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_1),
  .vio_tg_status_err_type              (vio_tg_status_err_type_1),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_1),
  .vio_tg_status_done                  (boot_mode_done_1),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_1),
  .tg_ila_debug                        (tg_ila_debug_1),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_01_AWID    = axi4_hbm_chs_li[1].awid;
  assign AXI_01_AWADDR  = axi4_hbm_chs_li[1].awaddr[0][32:0];
  assign AXI_01_AWLEN   = axi4_hbm_chs_li[1].awlen;
  assign AXI_01_AWSIZE  = axi4_hbm_chs_li[1].awsize;
  assign AXI_01_AWBURST = axi4_hbm_chs_li[1].awburst;
  // assign AXI_01_awlock = axi4_hbm_chs_li[1].awlock;
  assign AXI_01_AWCACHE = axi4_hbm_chs_li[1].awcache;
  assign AXI_01_AWPROT  = axi4_hbm_chs_li[1].awprot;
  assign AXI_01_AWVALID = axi4_hbm_chs_li[1].awvalid;
  assign AXI_01_WDATA   = axi4_hbm_chs_li[1].wdata;
  assign AXI_01_WSTRB   = axi4_hbm_chs_li[1].wstrb;
  assign AXI_01_WLAST   = axi4_hbm_chs_li[1].wlast;
  assign AXI_01_WVALID  = axi4_hbm_chs_li[1].wvalid;
  assign AXI_01_BREADY  = axi4_hbm_chs_li[1].bready;
  assign AXI_01_ARID    = axi4_hbm_chs_li[1].arid;
  assign AXI_01_ARADDR  = axi4_hbm_chs_li[1].araddr[0][32:0];
  assign AXI_01_ARLEN   = axi4_hbm_chs_li[1].arlen;
  assign AXI_01_ARSIZE  = axi4_hbm_chs_li[1].arsize;
  assign AXI_01_ARBURST = axi4_hbm_chs_li[1].arburst;
  // assign ( = axi4_hbm_chs_li[1].arburst;
  assign AXI_01_ARCACHE = axi4_hbm_chs_li[1].arcache;
  // assign ( = axi4_hbm_chs_li[1].arprot;
  assign AXI_01_ARVALID = axi4_hbm_chs_li[1].arvalid;
  assign AXI_01_RREADY  = axi4_hbm_chs_li[1].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[1].awready = AXI_01_AWREADY;
  assign axi4_hbm_chs_lo[1].wready  = AXI_01_WREADY;
  assign axi4_hbm_chs_lo[1].bid     = AXI_01_BID;
  assign axi4_hbm_chs_lo[1].bresp   = AXI_01_BRESP;
  assign axi4_hbm_chs_lo[1].bvalid  = AXI_01_BVALID;
  assign axi4_hbm_chs_lo[1].arready = AXI_01_ARREADY;
  assign axi4_hbm_chs_lo[1].rid     = AXI_01_RID;
  assign axi4_hbm_chs_lo[1].rresp   = AXI_01_RRESP;
  assign axi4_hbm_chs_lo[1].rvalid  = AXI_01_RVALID;
  assign axi4_hbm_chs_lo[1].rdata   = AXI_01_RDATA;
  assign axi4_hbm_chs_lo[1].rlast   = AXI_01_RLAST;


assign  vio_tg_rst_1 =  1'd0;
assign  i_force_vio_tg_status_done_1 = 16'h0000;
assign  i_vio_enable_atg_axi_x_1 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_1 =  16'hffff;
assign  vio_tg_restart_1 =  'd0;
assign  vio_tg_pause_1 =  'd0;
assign  vio_tg_err_chk_en_1 =  'd0;
assign  vio_tg_err_clear_1 =  'd0;
assign  vio_tg_err_clear_all_1 =  'd0;
assign  vio_tg_err_continue_1 =  'd0;
assign  vio_tg_instr_program_en_1 =  'd0;
assign  vio_tg_direct_instr_en_1 =  'd0;
assign  vio_tg_instr_num_1 =  'd0;
assign  vio_tg_instr_addr_mode_1 =  'd0;
assign  vio_tg_instr_data_mode_1 =  'd0;
assign  vio_tg_instr_rw_mode_1 =  'd0;
assign  vio_tg_instr_rw_submode_1 =  'd0;
assign  vio_tg_instr_victim_mode_1 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_1 =  'd0;
assign  vio_tg_instr_victim_select_1 =  'd0;
assign  vio_tg_instr_num_of_iter_1 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_1 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_1 =  'd0;
assign  vio_tg_instr_nxt_instr_1 =  'd0;
assign  vio_tg_seed_program_en_1 =  'd0;
assign  vio_tg_seed_num_1 =  'd0;
assign  vio_tg_seed_1 =  'd0;
assign  vio_tg_glb_start_addr_1 = 33'h0_1100_0000;

always@(posedge AXI_ACLK0_st0_buf or negedge axi_rst0_st0_n) begin
  if (~axi_rst0_st0_n) begin
    rd_cnt_01 <= 5'b0;
  end else if (AXI_01_RVALID && AXI_01_RREADY) begin
    rd_cnt_01 <= rd_cnt_01 + 1'b1;
  end
end

always@(posedge AXI_ACLK0_st0_buf or negedge axi_rst0_st0_n) begin
  if (~axi_rst0_st0_n) begin
    wr_cnt_01 <= 5'b0;
  end else if (AXI_01_BVALID && AXI_01_BREADY) begin
    wr_cnt_01 <= wr_cnt_01 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 1
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (1)
) u_axi_pmon_1 (
  .axi_arst_n              (axi_rst0_st0_n    ),
  .axi_aclk                (AXI_ACLK0_st0_buf ),
  .axi_awid                (AXI_01_AWID),
  .axi_awaddr              (AXI_01_AWADDR),
  .axi_awlen               (AXI_01_AWLEN),
  .axi_awsize              (AXI_01_AWSIZE),
  .axi_awburst             (AXI_01_AWBURST),
  .axi_awcache             (AXI_01_AWCACHE),
  .axi_awprot              (AXI_01_AWPROT),
  .axi_awvalid             (AXI_01_AWVALID),
  .axi_awready             (AXI_01_AWREADY),
  .axi_wdata               (AXI_01_WDATA),
  .axi_wstrb               (AXI_01_WSTRB),
  .axi_wlast               (AXI_01_WLAST),
  .axi_wvalid              (AXI_01_WVALID),
  .axi_wready              (AXI_01_WREADY),
  .axi_bready              (AXI_01_BREADY),
  .axi_bid                 (AXI_01_BID),
  .axi_bresp               (AXI_01_BRESP),
  .axi_bvalid              (AXI_01_BVALID),
  .axi_arid                (AXI_01_ARID),
  .axi_araddr              (AXI_01_ARADDR),
  .axi_arlen               (AXI_01_ARLEN),
  .axi_arsize              (AXI_01_ARSIZE),
  .axi_arburst             (AXI_01_ARBURST),
  .axi_arcache             (AXI_01_ARCACHE),
  .axi_arvalid             (AXI_01_ARVALID),
  .axi_arready             (AXI_01_ARREADY),
  .axi_rready              (AXI_01_RREADY),
  .axi_rid                 (AXI_01_RID),
  .axi_rdata               (AXI_01_RDATA),
  .axi_rresp               (AXI_01_RRESP),
  .axi_rlast               (AXI_01_RLAST),
  .axi_rvalid              (AXI_01_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 2
////////////////////////////////////////////////////////////////////////////////
// assign AXI_02_ARADDR = {vio_tg_glb_start_addr_2[32:28],o_m_axi_araddr_2[27:0]};
// assign AXI_02_AWADDR = {vio_tg_glb_start_addr_2[32:28],o_m_axi_awaddr_2[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_2 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK1_st0_buf),
  .i_rst                               (~axi_rst1_st0_n),
  .i_init_calib_complete               (apb_seq_complete_1_st0_r2),
  .compare_error                       (axi_02_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_2),
  .vio_tg_start                        (vio_tg_start_2),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_2),
  .vio_tg_err_clear                    (vio_tg_err_clear_2),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_2),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_2),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_2),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_2),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_2),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_2),
  .vio_tg_restart                      (vio_tg_restart_2),
  .vio_tg_pause                        (vio_tg_pause_2),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_2),
  .vio_tg_err_continue                 (vio_tg_err_continue_2),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_2),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_2),
  .vio_tg_instr_num                    (vio_tg_instr_num_2),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_2),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_2),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_2),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_2),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_2),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_2),
  .vio_tg_seed_num                     (vio_tg_seed_num_2),
  .vio_tg_seed                         (vio_tg_seed_2),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_2),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_2),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_2),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_2),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_2),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_2),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_2),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_2),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_2),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_2),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_2),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_2),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_2),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_2),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_2),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_2),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_2),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_2),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_2),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_2),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_2),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_2),
  .vio_tg_status_err_type              (vio_tg_status_err_type_2),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_2),
  .vio_tg_status_done                  (boot_mode_done_2),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_2),
  .tg_ila_debug                        (tg_ila_debug_2),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_02_AWID    = axi4_hbm_chs_li[2].awid;
  assign AXI_02_AWADDR  = axi4_hbm_chs_li[2].awaddr[0][32:0];
  assign AXI_02_AWLEN   = axi4_hbm_chs_li[2].awlen;
  assign AXI_02_AWSIZE  = axi4_hbm_chs_li[2].awsize;
  assign AXI_02_AWBURST = axi4_hbm_chs_li[2].awburst;
  // assign AXI_02_awlock = axi4_hbm_chs_li[2].awlock;
  assign AXI_02_AWCACHE = axi4_hbm_chs_li[2].awcache;
  assign AXI_02_AWPROT  = axi4_hbm_chs_li[2].awprot;
  assign AXI_02_AWVALID = axi4_hbm_chs_li[2].awvalid;
  assign AXI_02_WDATA   = axi4_hbm_chs_li[2].wdata;
  assign AXI_02_WSTRB   = axi4_hbm_chs_li[2].wstrb;
  assign AXI_02_WLAST   = axi4_hbm_chs_li[2].wlast;
  assign AXI_02_WVALID  = axi4_hbm_chs_li[2].wvalid;
  assign AXI_02_BREADY  = axi4_hbm_chs_li[2].bready;
  assign AXI_02_ARID    = axi4_hbm_chs_li[2].arid;
  assign AXI_02_ARADDR  = axi4_hbm_chs_li[2].araddr[0][32:0];
  assign AXI_02_ARLEN   = axi4_hbm_chs_li[2].arlen;
  assign AXI_02_ARSIZE  = axi4_hbm_chs_li[2].arsize;
  assign AXI_02_ARBURST = axi4_hbm_chs_li[2].arburst;
  // assign ( = axi4_hbm_chs_li[2].arburst;
  assign AXI_02_ARCACHE = axi4_hbm_chs_li[2].arcache;
  // assign ( = axi4_hbm_chs_li[2].arprot;
  assign AXI_02_ARVALID = axi4_hbm_chs_li[2].arvalid;
  assign AXI_02_RREADY  = axi4_hbm_chs_li[2].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[2].awready = AXI_02_AWREADY;
  assign axi4_hbm_chs_lo[2].wready  = AXI_02_WREADY;
  assign axi4_hbm_chs_lo[2].bid     = AXI_02_BID;
  assign axi4_hbm_chs_lo[2].bresp   = AXI_02_BRESP;
  assign axi4_hbm_chs_lo[2].bvalid  = AXI_02_BVALID;
  assign axi4_hbm_chs_lo[2].arready = AXI_02_ARREADY;
  assign axi4_hbm_chs_lo[2].rid     = AXI_02_RID;
  assign axi4_hbm_chs_lo[2].rresp   = AXI_02_RRESP;
  assign axi4_hbm_chs_lo[2].rvalid  = AXI_02_RVALID;
  assign axi4_hbm_chs_lo[2].rdata   = AXI_02_RDATA;
  assign axi4_hbm_chs_lo[2].rlast   = AXI_02_RLAST;


assign  vio_tg_rst_2 =  1'd0;
assign  i_force_vio_tg_status_done_2 = 16'h0000;
assign  i_vio_enable_atg_axi_x_2 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_2 =  16'hffff;
assign  vio_tg_restart_2 =  'd0;
assign  vio_tg_pause_2 =  'd0;
assign  vio_tg_err_chk_en_2 =  'd0;
assign  vio_tg_err_clear_2 =  'd0;
assign  vio_tg_err_clear_all_2 =  'd0;
assign  vio_tg_err_continue_2 =  'd0;
assign  vio_tg_instr_program_en_2 =  'd0;
assign  vio_tg_direct_instr_en_2 =  'd0;
assign  vio_tg_instr_num_2 =  'd0;
assign  vio_tg_instr_addr_mode_2 =  'd0;
assign  vio_tg_instr_data_mode_2 =  'd0;
assign  vio_tg_instr_rw_mode_2 =  'd0;
assign  vio_tg_instr_rw_submode_2 =  'd0;
assign  vio_tg_instr_victim_mode_2 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_2 =  'd0;
assign  vio_tg_instr_victim_select_2 =  'd0;
assign  vio_tg_instr_num_of_iter_2 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_2 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_2 =  'd0;
assign  vio_tg_instr_nxt_instr_2 =  'd0;
assign  vio_tg_seed_program_en_2 =  'd0;
assign  vio_tg_seed_num_2 =  'd0;
assign  vio_tg_seed_2 =  'd0;
assign  vio_tg_glb_start_addr_2 = 33'h0_2200_0000;

always@(posedge AXI_ACLK1_st0_buf or negedge axi_rst1_st0_n) begin
  if (~axi_rst1_st0_n) begin
    rd_cnt_02 <= 5'b0;
  end else if (AXI_02_RVALID && AXI_02_RREADY) begin
    rd_cnt_02 <= rd_cnt_02 + 1'b1;
  end
end

always@(posedge AXI_ACLK1_st0_buf or negedge axi_rst1_st0_n) begin
  if (~axi_rst1_st0_n) begin
    wr_cnt_02 <= 5'b0;
  end else if (AXI_02_BVALID && AXI_02_BREADY) begin
    wr_cnt_02 <= wr_cnt_02 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 2
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (2)
) u_axi_pmon_2 (
  .axi_arst_n              (axi_rst1_st0_n    ),
  .axi_aclk                (AXI_ACLK1_st0_buf ),
  .axi_awid                (AXI_02_AWID),
  .axi_awaddr              (AXI_02_AWADDR),
  .axi_awlen               (AXI_02_AWLEN),
  .axi_awsize              (AXI_02_AWSIZE),
  .axi_awburst             (AXI_02_AWBURST),
  .axi_awcache             (AXI_02_AWCACHE),
  .axi_awprot              (AXI_02_AWPROT),
  .axi_awvalid             (AXI_02_AWVALID),
  .axi_awready             (AXI_02_AWREADY),
  .axi_wdata               (AXI_02_WDATA),
  .axi_wstrb               (AXI_02_WSTRB),
  .axi_wlast               (AXI_02_WLAST),
  .axi_wvalid              (AXI_02_WVALID),
  .axi_wready              (AXI_02_WREADY),
  .axi_bready              (AXI_02_BREADY),
  .axi_bid                 (AXI_02_BID),
  .axi_bresp               (AXI_02_BRESP),
  .axi_bvalid              (AXI_02_BVALID),
  .axi_arid                (AXI_02_ARID),
  .axi_araddr              (AXI_02_ARADDR),
  .axi_arlen               (AXI_02_ARLEN),
  .axi_arsize              (AXI_02_ARSIZE),
  .axi_arburst             (AXI_02_ARBURST),
  .axi_arcache             (AXI_02_ARCACHE),
  .axi_arvalid             (AXI_02_ARVALID),
  .axi_arready             (AXI_02_ARREADY),
  .axi_rready              (AXI_02_RREADY),
  .axi_rid                 (AXI_02_RID),
  .axi_rdata               (AXI_02_RDATA),
  .axi_rresp               (AXI_02_RRESP),
  .axi_rlast               (AXI_02_RLAST),
  .axi_rvalid              (AXI_02_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 3
////////////////////////////////////////////////////////////////////////////////
// assign AXI_03_ARADDR = {vio_tg_glb_start_addr_3[32:28],o_m_axi_araddr_3[27:0]};
// assign AXI_03_AWADDR = {vio_tg_glb_start_addr_3[32:28],o_m_axi_awaddr_3[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_3 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK1_st0_buf),
  .i_rst                               (~axi_rst1_st0_n),
  .i_init_calib_complete               (apb_seq_complete_1_st0_r2),
  .compare_error                       (axi_03_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_3),
  .vio_tg_start                        (vio_tg_start_3),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_3),
  .vio_tg_err_clear                    (vio_tg_err_clear_3),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_3),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_3),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_3),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_3),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_3),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_3),
  .vio_tg_restart                      (vio_tg_restart_3),
  .vio_tg_pause                        (vio_tg_pause_3),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_3),
  .vio_tg_err_continue                 (vio_tg_err_continue_3),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_3),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_3),
  .vio_tg_instr_num                    (vio_tg_instr_num_3),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_3),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_3),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_3),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_3),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_3),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_3),
  .vio_tg_seed_num                     (vio_tg_seed_num_3),
  .vio_tg_seed                         (vio_tg_seed_3),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_3),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_3),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_3),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_3),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_3),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_3),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_3),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_3),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_3),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_3),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_3),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_3),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_3),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_3),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_3),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_3),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_3),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_3),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_3),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_3),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_3),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_3),
  .vio_tg_status_err_type              (vio_tg_status_err_type_3),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_3),
  .vio_tg_status_done                  (boot_mode_done_3),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_3),
  .tg_ila_debug                        (tg_ila_debug_3),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_03_AWID    = axi4_hbm_chs_li[3].awid;
  assign AXI_03_AWADDR  = axi4_hbm_chs_li[3].awaddr[0][32:0];
  assign AXI_03_AWLEN   = axi4_hbm_chs_li[3].awlen;
  assign AXI_03_AWSIZE  = axi4_hbm_chs_li[3].awsize;
  assign AXI_03_AWBURST = axi4_hbm_chs_li[3].awburst;
  // assign AXI_03_awlock = axi4_hbm_chs_li[3].awlock;
  assign AXI_03_AWCACHE = axi4_hbm_chs_li[3].awcache;
  assign AXI_03_AWPROT  = axi4_hbm_chs_li[3].awprot;
  assign AXI_03_AWVALID = axi4_hbm_chs_li[3].awvalid;
  assign AXI_03_WDATA   = axi4_hbm_chs_li[3].wdata;
  assign AXI_03_WSTRB   = axi4_hbm_chs_li[3].wstrb;
  assign AXI_03_WLAST   = axi4_hbm_chs_li[3].wlast;
  assign AXI_03_WVALID  = axi4_hbm_chs_li[3].wvalid;
  assign AXI_03_BREADY  = axi4_hbm_chs_li[3].bready;
  assign AXI_03_ARID    = axi4_hbm_chs_li[3].arid;
  assign AXI_03_ARADDR  = axi4_hbm_chs_li[3].araddr[0][32:0];
  assign AXI_03_ARLEN   = axi4_hbm_chs_li[3].arlen;
  assign AXI_03_ARSIZE  = axi4_hbm_chs_li[3].arsize;
  assign AXI_03_ARBURST = axi4_hbm_chs_li[3].arburst;
  // assign ( = axi4_hbm_chs_li[3].arburst;
  assign AXI_03_ARCACHE = axi4_hbm_chs_li[3].arcache;
  // assign ( = axi4_hbm_chs_li[3].arprot;
  assign AXI_03_ARVALID = axi4_hbm_chs_li[3].arvalid;
  assign AXI_03_RREADY  = axi4_hbm_chs_li[3].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[3].awready = AXI_03_AWREADY;
  assign axi4_hbm_chs_lo[3].wready  = AXI_03_WREADY;
  assign axi4_hbm_chs_lo[3].bid     = AXI_03_BID;
  assign axi4_hbm_chs_lo[3].bresp   = AXI_03_BRESP;
  assign axi4_hbm_chs_lo[3].bvalid  = AXI_03_BVALID;
  assign axi4_hbm_chs_lo[3].arready = AXI_03_ARREADY;
  assign axi4_hbm_chs_lo[3].rid     = AXI_03_RID;
  assign axi4_hbm_chs_lo[3].rresp   = AXI_03_RRESP;
  assign axi4_hbm_chs_lo[3].rvalid  = AXI_03_RVALID;
  assign axi4_hbm_chs_lo[3].rdata   = AXI_03_RDATA;
  assign axi4_hbm_chs_lo[3].rlast   = AXI_03_RLAST;


assign  vio_tg_rst_3 =  1'd0;
assign  i_force_vio_tg_status_done_3 = 16'h0000;
assign  i_vio_enable_atg_axi_x_3 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_3 =  16'hffff;
assign  vio_tg_restart_3 =  'd0;
assign  vio_tg_pause_3 =  'd0;
assign  vio_tg_err_chk_en_3 =  'd0;
assign  vio_tg_err_clear_3 =  'd0;
assign  vio_tg_err_clear_all_3 =  'd0;
assign  vio_tg_err_continue_3 =  'd0;
assign  vio_tg_instr_program_en_3 =  'd0;
assign  vio_tg_direct_instr_en_3 =  'd0;
assign  vio_tg_instr_num_3 =  'd0;
assign  vio_tg_instr_addr_mode_3 =  'd0;
assign  vio_tg_instr_data_mode_3 =  'd0;
assign  vio_tg_instr_rw_mode_3 =  'd0;
assign  vio_tg_instr_rw_submode_3 =  'd0;
assign  vio_tg_instr_victim_mode_3 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_3 =  'd0;
assign  vio_tg_instr_victim_select_3 =  'd0;
assign  vio_tg_instr_num_of_iter_3 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_3 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_3 =  'd0;
assign  vio_tg_instr_nxt_instr_3 =  'd0;
assign  vio_tg_seed_program_en_3 =  'd0;
assign  vio_tg_seed_num_3 =  'd0;
assign  vio_tg_seed_3 =  'd0;
assign  vio_tg_glb_start_addr_3 = 33'h0_3300_0000;

always@(posedge AXI_ACLK1_st0_buf or negedge axi_rst1_st0_n) begin
  if (~axi_rst1_st0_n) begin
    rd_cnt_03 <= 5'b0;
  end else if (AXI_03_RVALID && AXI_03_RREADY) begin
    rd_cnt_03 <= rd_cnt_03 + 1'b1;
  end
end

always@(posedge AXI_ACLK1_st0_buf or negedge axi_rst1_st0_n) begin
  if (~axi_rst1_st0_n) begin
    wr_cnt_03 <= 5'b0;
  end else if (AXI_03_BVALID && AXI_03_BREADY) begin
    wr_cnt_03 <= wr_cnt_03 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 3
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (3)
) u_axi_pmon_3 (
  .axi_arst_n              (axi_rst1_st0_n    ),
  .axi_aclk                (AXI_ACLK1_st0_buf ),
  .axi_awid                (AXI_03_AWID),
  .axi_awaddr              (AXI_03_AWADDR),
  .axi_awlen               (AXI_03_AWLEN),
  .axi_awsize              (AXI_03_AWSIZE),
  .axi_awburst             (AXI_03_AWBURST),
  .axi_awcache             (AXI_03_AWCACHE),
  .axi_awprot              (AXI_03_AWPROT),
  .axi_awvalid             (AXI_03_AWVALID),
  .axi_awready             (AXI_03_AWREADY),
  .axi_wdata               (AXI_03_WDATA),
  .axi_wstrb               (AXI_03_WSTRB),
  .axi_wlast               (AXI_03_WLAST),
  .axi_wvalid              (AXI_03_WVALID),
  .axi_wready              (AXI_03_WREADY),
  .axi_bready              (AXI_03_BREADY),
  .axi_bid                 (AXI_03_BID),
  .axi_bresp               (AXI_03_BRESP),
  .axi_bvalid              (AXI_03_BVALID),
  .axi_arid                (AXI_03_ARID),
  .axi_araddr              (AXI_03_ARADDR),
  .axi_arlen               (AXI_03_ARLEN),
  .axi_arsize              (AXI_03_ARSIZE),
  .axi_arburst             (AXI_03_ARBURST),
  .axi_arcache             (AXI_03_ARCACHE),
  .axi_arvalid             (AXI_03_ARVALID),
  .axi_arready             (AXI_03_ARREADY),
  .axi_rready              (AXI_03_RREADY),
  .axi_rid                 (AXI_03_RID),
  .axi_rdata               (AXI_03_RDATA),
  .axi_rresp               (AXI_03_RRESP),
  .axi_rlast               (AXI_03_RLAST),
  .axi_rvalid              (AXI_03_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 4
////////////////////////////////////////////////////////////////////////////////
// assign AXI_04_ARADDR = {vio_tg_glb_start_addr_4[32:28],o_m_axi_araddr_4[27:0]};
// assign AXI_04_AWADDR = {vio_tg_glb_start_addr_4[32:28],o_m_axi_awaddr_4[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_4 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK2_st0_buf),
  .i_rst                               (~axi_rst2_st0_n),
  .i_init_calib_complete               (apb_seq_complete_2_st0_r2),
  .compare_error                       (axi_04_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_4),
  .vio_tg_start                        (vio_tg_start_4),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_4),
  .vio_tg_err_clear                    (vio_tg_err_clear_4),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_4),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_4),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_4),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_4),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_4),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_4),
  .vio_tg_restart                      (vio_tg_restart_4),
  .vio_tg_pause                        (vio_tg_pause_4),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_4),
  .vio_tg_err_continue                 (vio_tg_err_continue_4),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_4),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_4),
  .vio_tg_instr_num                    (vio_tg_instr_num_4),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_4),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_4),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_4),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_4),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_4),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_4),
  .vio_tg_seed_num                     (vio_tg_seed_num_4),
  .vio_tg_seed                         (vio_tg_seed_4),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_4),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_4),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_4),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_4),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_4),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_4),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_4),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_4),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_4),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_4),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_4),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_4),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_4),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_4),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_4),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_4),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_4),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_4),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_4),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_4),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_4),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_4),
  .vio_tg_status_err_type              (vio_tg_status_err_type_4),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_4),
  .vio_tg_status_done                  (boot_mode_done_4),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_4),
  .tg_ila_debug                        (tg_ila_debug_4),
  .tg_qdriv_submode11_app_rd           (1'b0),
 // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_04_AWID    = axi4_hbm_chs_li[4].awid;
  assign AXI_04_AWADDR  = axi4_hbm_chs_li[4].awaddr[0][32:0];
  assign AXI_04_AWLEN   = axi4_hbm_chs_li[4].awlen;
  assign AXI_04_AWSIZE  = axi4_hbm_chs_li[4].awsize;
  assign AXI_04_AWBURST = axi4_hbm_chs_li[4].awburst;
  // assign AXI_04_awlock = axi4_hbm_chs_li[4].awlock;
  assign AXI_04_AWCACHE = axi4_hbm_chs_li[4].awcache;
  assign AXI_04_AWPROT  = axi4_hbm_chs_li[4].awprot;
  assign AXI_04_AWVALID = axi4_hbm_chs_li[4].awvalid;
  assign AXI_04_WDATA   = axi4_hbm_chs_li[4].wdata;
  assign AXI_04_WSTRB   = axi4_hbm_chs_li[4].wstrb;
  assign AXI_04_WLAST   = axi4_hbm_chs_li[4].wlast;
  assign AXI_04_WVALID  = axi4_hbm_chs_li[4].wvalid;
  assign AXI_04_BREADY  = axi4_hbm_chs_li[4].bready;
  assign AXI_04_ARID    = axi4_hbm_chs_li[4].arid;
  assign AXI_04_ARADDR  = axi4_hbm_chs_li[4].araddr[0][32:0];
  assign AXI_04_ARLEN   = axi4_hbm_chs_li[4].arlen;
  assign AXI_04_ARSIZE  = axi4_hbm_chs_li[4].arsize;
  assign AXI_04_ARBURST = axi4_hbm_chs_li[4].arburst;
  // assign ( = axi4_hbm_chs_li[4].arburst;
  assign AXI_04_ARCACHE = axi4_hbm_chs_li[4].arcache;
  // assign ( = axi4_hbm_chs_li[4].arprot;
  assign AXI_04_ARVALID = axi4_hbm_chs_li[4].arvalid;
  assign AXI_04_RREADY  = axi4_hbm_chs_li[4].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[4].awready = AXI_04_AWREADY;
  assign axi4_hbm_chs_lo[4].wready  = AXI_04_WREADY;
  assign axi4_hbm_chs_lo[4].bid     = AXI_04_BID;
  assign axi4_hbm_chs_lo[4].bresp   = AXI_04_BRESP;
  assign axi4_hbm_chs_lo[4].bvalid  = AXI_04_BVALID;
  assign axi4_hbm_chs_lo[4].arready = AXI_04_ARREADY;
  assign axi4_hbm_chs_lo[4].rid     = AXI_04_RID;
  assign axi4_hbm_chs_lo[4].rresp   = AXI_04_RRESP;
  assign axi4_hbm_chs_lo[4].rvalid  = AXI_04_RVALID;
  assign axi4_hbm_chs_lo[4].rdata   = AXI_04_RDATA;
  assign axi4_hbm_chs_lo[4].rlast   = AXI_04_RLAST;

assign  vio_tg_rst_4 =  1'd0;
assign  i_force_vio_tg_status_done_4 = 16'h0000;
assign  i_vio_enable_atg_axi_x_4 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_4 =  16'hffff;
assign  vio_tg_restart_4 =  'd0;
assign  vio_tg_pause_4 =  'd0;
assign  vio_tg_err_chk_en_4 =  'd0;
assign  vio_tg_err_clear_4 =  'd0;
assign  vio_tg_err_clear_all_4 =  'd0;
assign  vio_tg_err_continue_4 =  'd0;
assign  vio_tg_instr_program_en_4 =  'd0;
assign  vio_tg_direct_instr_en_4 =  'd0;
assign  vio_tg_instr_num_4 =  'd0;
assign  vio_tg_instr_addr_mode_4 =  'd0;
assign  vio_tg_instr_data_mode_4 =  'd0;
assign  vio_tg_instr_rw_mode_4 =  'd0;
assign  vio_tg_instr_rw_submode_4 =  'd0;
assign  vio_tg_instr_victim_mode_4 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_4 =  'd0;
assign  vio_tg_instr_victim_select_4 =  'd0;
assign  vio_tg_instr_num_of_iter_4 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_4 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_4 =  'd0;
assign  vio_tg_instr_nxt_instr_4 =  'd0;
assign  vio_tg_seed_program_en_4 =  'd0;
assign  vio_tg_seed_num_4 =  'd0;
assign  vio_tg_seed_4 =  'd0;
assign  vio_tg_glb_start_addr_4 = 33'h0_4400_0000;

always@(posedge AXI_ACLK2_st0_buf or negedge axi_rst2_st0_n) begin
  if (~axi_rst2_st0_n) begin
    rd_cnt_04 <= 5'b0;
  end else if (AXI_04_RVALID && AXI_04_RREADY) begin
    rd_cnt_04 <= rd_cnt_04 + 1'b1;
  end
end

always@(posedge AXI_ACLK2_st0_buf or negedge axi_rst2_st0_n) begin
  if (~axi_rst2_st0_n) begin
    wr_cnt_04 <= 5'b0;
  end else if (AXI_04_BVALID && AXI_04_BREADY) begin
    wr_cnt_04 <= wr_cnt_04 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 4
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (4)
) u_axi_pmon_4 (
  .axi_arst_n              (axi_rst2_st0_n    ),
  .axi_aclk                (AXI_ACLK2_st0_buf ),
  .axi_awid                (AXI_04_AWID),
  .axi_awaddr              (AXI_04_AWADDR),
  .axi_awlen               (AXI_04_AWLEN),
  .axi_awsize              (AXI_04_AWSIZE),
  .axi_awburst             (AXI_04_AWBURST),
  .axi_awcache             (AXI_04_AWCACHE),
  .axi_awprot              (AXI_04_AWPROT),
  .axi_awvalid             (AXI_04_AWVALID),
  .axi_awready             (AXI_04_AWREADY),
  .axi_wdata               (AXI_04_WDATA),
  .axi_wstrb               (AXI_04_WSTRB),
  .axi_wlast               (AXI_04_WLAST),
  .axi_wvalid              (AXI_04_WVALID),
  .axi_wready              (AXI_04_WREADY),
  .axi_bready              (AXI_04_BREADY),
  .axi_bid                 (AXI_04_BID),
  .axi_bresp               (AXI_04_BRESP),
  .axi_bvalid              (AXI_04_BVALID),
  .axi_arid                (AXI_04_ARID),
  .axi_araddr              (AXI_04_ARADDR),
  .axi_arlen               (AXI_04_ARLEN),
  .axi_arsize              (AXI_04_ARSIZE),
  .axi_arburst             (AXI_04_ARBURST),
  .axi_arcache             (AXI_04_ARCACHE),
  .axi_arvalid             (AXI_04_ARVALID),
  .axi_arready             (AXI_04_ARREADY),
  .axi_rready              (AXI_04_RREADY),
  .axi_rid                 (AXI_04_RID),
  .axi_rdata               (AXI_04_RDATA),
  .axi_rresp               (AXI_04_RRESP),
  .axi_rlast               (AXI_04_RLAST),
  .axi_rvalid              (AXI_04_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 5
////////////////////////////////////////////////////////////////////////////////
// assign AXI_05_ARADDR = {vio_tg_glb_start_addr_5[32:28],o_m_axi_araddr_5[27:0]};
// assign AXI_05_AWADDR = {vio_tg_glb_start_addr_5[32:28],o_m_axi_awaddr_5[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_5 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK2_st0_buf),
  .i_rst                               (~axi_rst2_st0_n),
  .i_init_calib_complete               (apb_seq_complete_2_st0_r2),
  .compare_error                       (axi_05_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_5),
  .vio_tg_start                        (vio_tg_start_5),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_5),
  .vio_tg_err_clear                    (vio_tg_err_clear_5),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_5),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_5),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_5),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_5),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_5),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_5),
  .vio_tg_restart                      (vio_tg_restart_5),
  .vio_tg_pause                        (vio_tg_pause_5),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_5),
  .vio_tg_err_continue                 (vio_tg_err_continue_5),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_5),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_5),
  .vio_tg_instr_num                    (vio_tg_instr_num_5),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_5),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_5),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_5),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_5),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_5),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_5),
  .vio_tg_seed_num                     (vio_tg_seed_num_5),
  .vio_tg_seed                         (vio_tg_seed_5),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_5),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_5),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_5),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_5),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_5),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_5),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_5),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_5),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_5),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_5),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_5),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_5),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_5),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_5),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_5),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_5),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_5),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_5),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_5),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_5),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_5),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_5),
  .vio_tg_status_err_type              (vio_tg_status_err_type_5),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_5),
  .vio_tg_status_done                  (boot_mode_done_5),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_5),
  .tg_ila_debug                        (tg_ila_debug_5),
  .tg_qdriv_submode11_app_rd           (1'b0),
 // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_05_AWID    = axi4_hbm_chs_li[5].awid;
  assign AXI_05_AWADDR  = axi4_hbm_chs_li[5].awaddr[0][32:0];
  assign AXI_05_AWLEN   = axi4_hbm_chs_li[5].awlen;
  assign AXI_05_AWSIZE  = axi4_hbm_chs_li[5].awsize;
  assign AXI_05_AWBURST = axi4_hbm_chs_li[5].awburst;
  // assign AXI_05_awlock = axi4_hbm_chs_li[5].awlock;
  assign AXI_05_AWCACHE = axi4_hbm_chs_li[5].awcache;
  assign AXI_05_AWPROT  = axi4_hbm_chs_li[5].awprot;
  assign AXI_05_AWVALID = axi4_hbm_chs_li[5].awvalid;
  assign AXI_05_WDATA   = axi4_hbm_chs_li[5].wdata;
  assign AXI_05_WSTRB   = axi4_hbm_chs_li[5].wstrb;
  assign AXI_05_WLAST   = axi4_hbm_chs_li[5].wlast;
  assign AXI_05_WVALID  = axi4_hbm_chs_li[5].wvalid;
  assign AXI_05_BREADY  = axi4_hbm_chs_li[5].bready;
  assign AXI_05_ARID    = axi4_hbm_chs_li[5].arid;
  assign AXI_05_ARADDR  = axi4_hbm_chs_li[5].araddr[0][32:0];
  assign AXI_05_ARLEN   = axi4_hbm_chs_li[5].arlen;
  assign AXI_05_ARSIZE  = axi4_hbm_chs_li[5].arsize;
  assign AXI_05_ARBURST = axi4_hbm_chs_li[5].arburst;
  // assign ( = axi4_hbm_chs_li[5].arburst;
  assign AXI_05_ARCACHE = axi4_hbm_chs_li[5].arcache;
  // assign ( = axi4_hbm_chs_li[5].arprot;
  assign AXI_05_ARVALID = axi4_hbm_chs_li[5].arvalid;
  assign AXI_05_RREADY  = axi4_hbm_chs_li[5].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[5].awready = AXI_05_AWREADY;
  assign axi4_hbm_chs_lo[5].wready  = AXI_05_WREADY;
  assign axi4_hbm_chs_lo[5].bid     = AXI_05_BID;
  assign axi4_hbm_chs_lo[5].bresp   = AXI_05_BRESP;
  assign axi4_hbm_chs_lo[5].bvalid  = AXI_05_BVALID;
  assign axi4_hbm_chs_lo[5].arready = AXI_05_ARREADY;
  assign axi4_hbm_chs_lo[5].rid     = AXI_05_RID;
  assign axi4_hbm_chs_lo[5].rresp   = AXI_05_RRESP;
  assign axi4_hbm_chs_lo[5].rvalid  = AXI_05_RVALID;
  assign axi4_hbm_chs_lo[5].rdata   = AXI_05_RDATA;
  assign axi4_hbm_chs_lo[5].rlast   = AXI_05_RLAST;

assign  vio_tg_rst_5 =  1'd0;
assign  i_force_vio_tg_status_done_5 = 16'h0000;
assign  i_vio_enable_atg_axi_x_5 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_5 =  16'hffff;
assign  vio_tg_restart_5 =  'd0;
assign  vio_tg_pause_5 =  'd0;
assign  vio_tg_err_chk_en_5 =  'd0;
assign  vio_tg_err_clear_5 =  'd0;
assign  vio_tg_err_clear_all_5 =  'd0;
assign  vio_tg_err_continue_5 =  'd0;
assign  vio_tg_instr_program_en_5 =  'd0;
assign  vio_tg_direct_instr_en_5 =  'd0;
assign  vio_tg_instr_num_5 =  'd0;
assign  vio_tg_instr_addr_mode_5 =  'd0;
assign  vio_tg_instr_data_mode_5 =  'd0;
assign  vio_tg_instr_rw_mode_5 =  'd0;
assign  vio_tg_instr_rw_submode_5 =  'd0;
assign  vio_tg_instr_victim_mode_5 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_5 =  'd0;
assign  vio_tg_instr_victim_select_5 =  'd0;
assign  vio_tg_instr_num_of_iter_5 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_5 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_5 =  'd0;
assign  vio_tg_instr_nxt_instr_5 =  'd0;
assign  vio_tg_seed_program_en_5 =  'd0;
assign  vio_tg_seed_num_5 =  'd0;
assign  vio_tg_seed_5 =  'd0;
assign  vio_tg_glb_start_addr_5 = 33'h0_5500_0000;

always@(posedge AXI_ACLK2_st0_buf or negedge axi_rst2_st0_n) begin
  if (~axi_rst2_st0_n) begin
    rd_cnt_05 <= 5'b0;
  end else if (AXI_05_RVALID && AXI_05_RREADY) begin
    rd_cnt_05 <= rd_cnt_05 + 1'b1;
  end
end

always@(posedge AXI_ACLK2_st0_buf or negedge axi_rst2_st0_n) begin
  if (~axi_rst2_st0_n) begin
    wr_cnt_05 <= 5'b0;
  end else if (AXI_05_BVALID && AXI_05_BREADY) begin
    wr_cnt_05 <= wr_cnt_05 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 5
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (5)
) u_axi_pmon_5 (
  .axi_arst_n              (axi_rst2_st0_n    ),
  .axi_aclk                (AXI_ACLK2_st0_buf ),
  .axi_awid                (AXI_05_AWID),
  .axi_awaddr              (AXI_05_AWADDR),
  .axi_awlen               (AXI_05_AWLEN),
  .axi_awsize              (AXI_05_AWSIZE),
  .axi_awburst             (AXI_05_AWBURST),
  .axi_awcache             (AXI_05_AWCACHE),
  .axi_awprot              (AXI_05_AWPROT),
  .axi_awvalid             (AXI_05_AWVALID),
  .axi_awready             (AXI_05_AWREADY),
  .axi_wdata               (AXI_05_WDATA),
  .axi_wstrb               (AXI_05_WSTRB),
  .axi_wlast               (AXI_05_WLAST),
  .axi_wvalid              (AXI_05_WVALID),
  .axi_wready              (AXI_05_WREADY),
  .axi_bready              (AXI_05_BREADY),
  .axi_bid                 (AXI_05_BID),
  .axi_bresp               (AXI_05_BRESP),
  .axi_bvalid              (AXI_05_BVALID),
  .axi_arid                (AXI_05_ARID),
  .axi_araddr              (AXI_05_ARADDR),
  .axi_arlen               (AXI_05_ARLEN),
  .axi_arsize              (AXI_05_ARSIZE),
  .axi_arburst             (AXI_05_ARBURST),
  .axi_arcache             (AXI_05_ARCACHE),
  .axi_arvalid             (AXI_05_ARVALID),
  .axi_arready             (AXI_05_ARREADY),
  .axi_rready              (AXI_05_RREADY),
  .axi_rid                 (AXI_05_RID),
  .axi_rdata               (AXI_05_RDATA),
  .axi_rresp               (AXI_05_RRESP),
  .axi_rlast               (AXI_05_RLAST),
  .axi_rvalid              (AXI_05_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 6
////////////////////////////////////////////////////////////////////////////////
// assign AXI_06_ARADDR = {vio_tg_glb_start_addr_6[32:28],o_m_axi_araddr_6[27:0]};
// assign AXI_06_AWADDR = {vio_tg_glb_start_addr_6[32:28],o_m_axi_awaddr_6[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_6 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK3_st0_buf),
  .i_rst                               (~axi_rst3_st0_n),
  .i_init_calib_complete               (apb_seq_complete_3_st0_r2),
  .compare_error                       (axi_06_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_6),
  .vio_tg_start                        (vio_tg_start_6),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_6),
  .vio_tg_err_clear                    (vio_tg_err_clear_6),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_6),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_6),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_6),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_6),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_6),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_6),
  .vio_tg_restart                      (vio_tg_restart_6),
  .vio_tg_pause                        (vio_tg_pause_6),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_6),
  .vio_tg_err_continue                 (vio_tg_err_continue_6),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_6),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_6),
  .vio_tg_instr_num                    (vio_tg_instr_num_6),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_6),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_6),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_6),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_6),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_6),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_6),
  .vio_tg_seed_num                     (vio_tg_seed_num_6),
  .vio_tg_seed                         (vio_tg_seed_6),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_6),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_6),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_6),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_6),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_6),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_6),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_6),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_6),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_6),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_6),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_6),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_6),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_6),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_6),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_6),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_6),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_6),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_6),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_6),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_6),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_6),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_6),
  .vio_tg_status_err_type              (vio_tg_status_err_type_6),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_6),
  .vio_tg_status_done                  (boot_mode_done_6),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_6),
  .tg_ila_debug                        (tg_ila_debug_6),
  .tg_qdriv_submode11_app_rd           (1'b0),
 // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_06_AWID    = axi4_hbm_chs_li[6].awid;
  assign AXI_06_AWADDR  = axi4_hbm_chs_li[6].awaddr[0][32:0];
  assign AXI_06_AWLEN   = axi4_hbm_chs_li[6].awlen;
  assign AXI_06_AWSIZE  = axi4_hbm_chs_li[6].awsize;
  assign AXI_06_AWBURST = axi4_hbm_chs_li[6].awburst;
  // assign AXI_06_awlock = axi4_hbm_chs_li[6].awlock;
  assign AXI_06_AWCACHE = axi4_hbm_chs_li[6].awcache;
  assign AXI_06_AWPROT  = axi4_hbm_chs_li[6].awprot;
  assign AXI_06_AWVALID = axi4_hbm_chs_li[6].awvalid;
  assign AXI_06_WDATA   = axi4_hbm_chs_li[6].wdata;
  assign AXI_06_WSTRB   = axi4_hbm_chs_li[6].wstrb;
  assign AXI_06_WLAST   = axi4_hbm_chs_li[6].wlast;
  assign AXI_06_WVALID  = axi4_hbm_chs_li[6].wvalid;
  assign AXI_06_BREADY  = axi4_hbm_chs_li[6].bready;
  assign AXI_06_ARID    = axi4_hbm_chs_li[6].arid;
  assign AXI_06_ARADDR  = axi4_hbm_chs_li[6].araddr[0][32:0];
  assign AXI_06_ARLEN   = axi4_hbm_chs_li[6].arlen;
  assign AXI_06_ARSIZE  = axi4_hbm_chs_li[6].arsize;
  assign AXI_06_ARBURST = axi4_hbm_chs_li[6].arburst;
  // assign ( = axi4_hbm_chs_li[6].arburst;
  assign AXI_06_ARCACHE = axi4_hbm_chs_li[6].arcache;
  // assign ( = axi4_hbm_chs_li[6].arprot;
  assign AXI_06_ARVALID = axi4_hbm_chs_li[6].arvalid;
  assign AXI_06_RREADY  = axi4_hbm_chs_li[6].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[6].awready = AXI_06_AWREADY;
  assign axi4_hbm_chs_lo[6].wready  = AXI_06_WREADY;
  assign axi4_hbm_chs_lo[6].bid     = AXI_06_BID;
  assign axi4_hbm_chs_lo[6].bresp   = AXI_06_BRESP;
  assign axi4_hbm_chs_lo[6].bvalid  = AXI_06_BVALID;
  assign axi4_hbm_chs_lo[6].arready = AXI_06_ARREADY;
  assign axi4_hbm_chs_lo[6].rid     = AXI_06_RID;
  assign axi4_hbm_chs_lo[6].rresp   = AXI_06_RRESP;
  assign axi4_hbm_chs_lo[6].rvalid  = AXI_06_RVALID;
  assign axi4_hbm_chs_lo[6].rdata   = AXI_06_RDATA;
  assign axi4_hbm_chs_lo[6].rlast   = AXI_06_RLAST;

assign  vio_tg_rst_6 =  1'd0;
assign  i_force_vio_tg_status_done_6 = 16'h0000;
assign  i_vio_enable_atg_axi_x_6 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_6 =  16'hffff;
assign  vio_tg_restart_6 =  'd0;
assign  vio_tg_pause_6 =  'd0;
assign  vio_tg_err_chk_en_6 =  'd0;
assign  vio_tg_err_clear_6 =  'd0;
assign  vio_tg_err_clear_all_6 =  'd0;
assign  vio_tg_err_continue_6 =  'd0;
assign  vio_tg_instr_program_en_6 =  'd0;
assign  vio_tg_direct_instr_en_6 =  'd0;
assign  vio_tg_instr_num_6 =  'd0;
assign  vio_tg_instr_addr_mode_6 =  'd0;
assign  vio_tg_instr_data_mode_6 =  'd0;
assign  vio_tg_instr_rw_mode_6 =  'd0;
assign  vio_tg_instr_rw_submode_6 =  'd0;
assign  vio_tg_instr_victim_mode_6 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_6 =  'd0;
assign  vio_tg_instr_victim_select_6 =  'd0;
assign  vio_tg_instr_num_of_iter_6 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_6 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_6 =  'd0;
assign  vio_tg_instr_nxt_instr_6 =  'd0;
assign  vio_tg_seed_program_en_6 =  'd0;
assign  vio_tg_seed_num_6 =  'd0;
assign  vio_tg_seed_6 =  'd0;
assign  vio_tg_glb_start_addr_6 = 33'h0_6600_0000;

always@(posedge AXI_ACLK3_st0_buf or negedge axi_rst3_st0_n) begin
  if (~axi_rst3_st0_n) begin
    rd_cnt_06 <= 5'b0;
  end else if (AXI_06_RVALID && AXI_06_RREADY) begin
    rd_cnt_06 <= rd_cnt_06 + 1'b1;
  end
end

always@(posedge AXI_ACLK3_st0_buf or negedge axi_rst3_st0_n) begin
  if (~axi_rst3_st0_n) begin
    wr_cnt_06 <= 5'b0;
  end else if (AXI_06_BVALID && AXI_06_BREADY) begin
    wr_cnt_06 <= wr_cnt_06 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 6
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (6)
) u_axi_pmon_6 (
  .axi_arst_n              (axi_rst3_st0_n    ),
  .axi_aclk                (AXI_ACLK3_st0_buf ),
  .axi_awid                (AXI_06_AWID),
  .axi_awaddr              (AXI_06_AWADDR),
  .axi_awlen               (AXI_06_AWLEN),
  .axi_awsize              (AXI_06_AWSIZE),
  .axi_awburst             (AXI_06_AWBURST),
  .axi_awcache             (AXI_06_AWCACHE),
  .axi_awprot              (AXI_06_AWPROT),
  .axi_awvalid             (AXI_06_AWVALID),
  .axi_awready             (AXI_06_AWREADY),
  .axi_wdata               (AXI_06_WDATA),
  .axi_wstrb               (AXI_06_WSTRB),
  .axi_wlast               (AXI_06_WLAST),
  .axi_wvalid              (AXI_06_WVALID),
  .axi_wready              (AXI_06_WREADY),
  .axi_bready              (AXI_06_BREADY),
  .axi_bid                 (AXI_06_BID),
  .axi_bresp               (AXI_06_BRESP),
  .axi_bvalid              (AXI_06_BVALID),
  .axi_arid                (AXI_06_ARID),
  .axi_araddr              (AXI_06_ARADDR),
  .axi_arlen               (AXI_06_ARLEN),
  .axi_arsize              (AXI_06_ARSIZE),
  .axi_arburst             (AXI_06_ARBURST),
  .axi_arcache             (AXI_06_ARCACHE),
  .axi_arvalid             (AXI_06_ARVALID),
  .axi_arready             (AXI_06_ARREADY),
  .axi_rready              (AXI_06_RREADY),
  .axi_rid                 (AXI_06_RID),
  .axi_rdata               (AXI_06_RDATA),
  .axi_rresp               (AXI_06_RRESP),
  .axi_rlast               (AXI_06_RLAST),
  .axi_rvalid              (AXI_06_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 7
////////////////////////////////////////////////////////////////////////////////
// assign AXI_07_ARADDR = {vio_tg_glb_start_addr_7[32:28],o_m_axi_araddr_7[27:0]};
// assign AXI_07_AWADDR = {vio_tg_glb_start_addr_7[32:28],o_m_axi_awaddr_7[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_7 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK3_st0_buf),
  .i_rst                               (~axi_rst3_st0_n),
  .i_init_calib_complete               (apb_seq_complete_3_st0_r2),
  .compare_error                       (axi_07_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_7),
  .vio_tg_start                        (vio_tg_start_7),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_7),
  .vio_tg_err_clear                    (vio_tg_err_clear_7),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_7),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_7),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_7),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_7),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_7),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_7),
  .vio_tg_restart                      (vio_tg_restart_7),
  .vio_tg_pause                        (vio_tg_pause_7),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_7),
  .vio_tg_err_continue                 (vio_tg_err_continue_7),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_7),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_7),
  .vio_tg_instr_num                    (vio_tg_instr_num_7),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_7),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_7),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_7),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_7),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_7),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_7),
  .vio_tg_seed_num                     (vio_tg_seed_num_7),
  .vio_tg_seed                         (vio_tg_seed_7),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_7),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_7),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_7),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_7),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_7),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_7),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_7),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_7),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_7),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_7),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_7),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_7),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_7),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_7),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_7),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_7),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_7),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_7),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_7),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_7),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_7),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_7),
  .vio_tg_status_err_type              (vio_tg_status_err_type_7),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_7),
  .vio_tg_status_done                  (boot_mode_done_7),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_7),
  .tg_ila_debug                        (tg_ila_debug_7),
  .tg_qdriv_submode11_app_rd           (1'b0),
 // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_07_AWID    = axi4_hbm_chs_li[7].awid;
  assign AXI_07_AWADDR  = axi4_hbm_chs_li[7].awaddr[0][32:0];
  assign AXI_07_AWLEN   = axi4_hbm_chs_li[7].awlen;
  assign AXI_07_AWSIZE  = axi4_hbm_chs_li[7].awsize;
  assign AXI_07_AWBURST = axi4_hbm_chs_li[7].awburst;
  // assign AXI_07_awlock = axi4_hbm_chs_li[7].awlock;
  assign AXI_07_AWCACHE = axi4_hbm_chs_li[7].awcache;
  assign AXI_07_AWPROT  = axi4_hbm_chs_li[7].awprot;
  assign AXI_07_AWVALID = axi4_hbm_chs_li[7].awvalid;
  assign AXI_07_WDATA   = axi4_hbm_chs_li[7].wdata;
  assign AXI_07_WSTRB   = axi4_hbm_chs_li[7].wstrb;
  assign AXI_07_WLAST   = axi4_hbm_chs_li[7].wlast;
  assign AXI_07_WVALID  = axi4_hbm_chs_li[7].wvalid;
  assign AXI_07_BREADY  = axi4_hbm_chs_li[7].bready;
  assign AXI_07_ARID    = axi4_hbm_chs_li[7].arid;
  assign AXI_07_ARADDR  = axi4_hbm_chs_li[7].araddr[0][32:0];
  assign AXI_07_ARLEN   = axi4_hbm_chs_li[7].arlen;
  assign AXI_07_ARSIZE  = axi4_hbm_chs_li[7].arsize;
  assign AXI_07_ARBURST = axi4_hbm_chs_li[7].arburst;
  // assign ( = axi4_hbm_chs_li[7].arburst;
  assign AXI_07_ARCACHE = axi4_hbm_chs_li[7].arcache;
  // assign ( = axi4_hbm_chs_li[7].arprot;
  assign AXI_07_ARVALID = axi4_hbm_chs_li[7].arvalid;
  assign AXI_07_RREADY  = axi4_hbm_chs_li[7].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[7].awready = AXI_07_AWREADY;
  assign axi4_hbm_chs_lo[7].wready  = AXI_07_WREADY;
  assign axi4_hbm_chs_lo[7].bid     = AXI_07_BID;
  assign axi4_hbm_chs_lo[7].bresp   = AXI_07_BRESP;
  assign axi4_hbm_chs_lo[7].bvalid  = AXI_07_BVALID;
  assign axi4_hbm_chs_lo[7].arready = AXI_07_ARREADY;
  assign axi4_hbm_chs_lo[7].rid     = AXI_07_RID;
  assign axi4_hbm_chs_lo[7].rresp   = AXI_07_RRESP;
  assign axi4_hbm_chs_lo[7].rvalid  = AXI_07_RVALID;
  assign axi4_hbm_chs_lo[7].rdata   = AXI_07_RDATA;
  assign axi4_hbm_chs_lo[7].rlast   = AXI_07_RLAST;

assign  vio_tg_rst_7 =  1'd0;
assign  i_force_vio_tg_status_done_7 = 16'h0000;
assign  i_vio_enable_atg_axi_x_7 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_7 =  16'hffff;
assign  vio_tg_restart_7 =  'd0;
assign  vio_tg_pause_7 =  'd0;
assign  vio_tg_err_chk_en_7 =  'd0;
assign  vio_tg_err_clear_7 =  'd0;
assign  vio_tg_err_clear_all_7 =  'd0;
assign  vio_tg_err_continue_7 =  'd0;
assign  vio_tg_instr_program_en_7 =  'd0;
assign  vio_tg_direct_instr_en_7 =  'd0;
assign  vio_tg_instr_num_7 =  'd0;
assign  vio_tg_instr_addr_mode_7 =  'd0;
assign  vio_tg_instr_data_mode_7 =  'd0;
assign  vio_tg_instr_rw_mode_7 =  'd0;
assign  vio_tg_instr_rw_submode_7 =  'd0;
assign  vio_tg_instr_victim_mode_7 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_7 =  'd0;
assign  vio_tg_instr_victim_select_7 =  'd0;
assign  vio_tg_instr_num_of_iter_7 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_7 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_7 =  'd0;
assign  vio_tg_instr_nxt_instr_7 =  'd0;
assign  vio_tg_seed_program_en_7 =  'd0;
assign  vio_tg_seed_num_7 =  'd0;
assign  vio_tg_seed_7 =  'd0;
assign  vio_tg_glb_start_addr_7 = 33'h0_7700_0000;

always@(posedge AXI_ACLK3_st0_buf or negedge axi_rst3_st0_n) begin
  if (~axi_rst3_st0_n) begin
    rd_cnt_07 <= 5'b0;
  end else if (AXI_07_RVALID && AXI_07_RREADY) begin
    rd_cnt_07 <= rd_cnt_07 + 1'b1;
  end
end

always@(posedge AXI_ACLK3_st0_buf or negedge axi_rst3_st0_n) begin
  if (~axi_rst3_st0_n) begin
    wr_cnt_07 <= 5'b0;
  end else if (AXI_07_BVALID && AXI_07_BREADY) begin
    wr_cnt_07 <= wr_cnt_07 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 7
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (7)
) u_axi_pmon_7 (
  .axi_arst_n              (axi_rst3_st0_n    ),
  .axi_aclk                (AXI_ACLK3_st0_buf ),
  .axi_awid                (AXI_07_AWID),
  .axi_awaddr              (AXI_07_AWADDR),
  .axi_awlen               (AXI_07_AWLEN),
  .axi_awsize              (AXI_07_AWSIZE),
  .axi_awburst             (AXI_07_AWBURST),
  .axi_awcache             (AXI_07_AWCACHE),
  .axi_awprot              (AXI_07_AWPROT),
  .axi_awvalid             (AXI_07_AWVALID),
  .axi_awready             (AXI_07_AWREADY),
  .axi_wdata               (AXI_07_WDATA),
  .axi_wstrb               (AXI_07_WSTRB),
  .axi_wlast               (AXI_07_WLAST),
  .axi_wvalid              (AXI_07_WVALID),
  .axi_wready              (AXI_07_WREADY),
  .axi_bready              (AXI_07_BREADY),
  .axi_bid                 (AXI_07_BID),
  .axi_bresp               (AXI_07_BRESP),
  .axi_bvalid              (AXI_07_BVALID),
  .axi_arid                (AXI_07_ARID),
  .axi_araddr              (AXI_07_ARADDR),
  .axi_arlen               (AXI_07_ARLEN),
  .axi_arsize              (AXI_07_ARSIZE),
  .axi_arburst             (AXI_07_ARBURST),
  .axi_arcache             (AXI_07_ARCACHE),
  .axi_arvalid             (AXI_07_ARVALID),
  .axi_arready             (AXI_07_ARREADY),
  .axi_rready              (AXI_07_RREADY),
  .axi_rid                 (AXI_07_RID),
  .axi_rdata               (AXI_07_RDATA),
  .axi_rresp               (AXI_07_RRESP),
  .axi_rlast               (AXI_07_RLAST),
  .axi_rvalid              (AXI_07_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 8
////////////////////////////////////////////////////////////////////////////////
// assign AXI_08_ARADDR = {vio_tg_glb_start_addr_8[32:28],o_m_axi_araddr_8[27:0]};
// assign AXI_08_AWADDR = {vio_tg_glb_start_addr_8[32:28],o_m_axi_awaddr_8[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_8 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK4_st0_buf),
  .i_rst                               (~axi_rst4_st0_n),
  .i_init_calib_complete               (apb_seq_complete_4_st0_r2),
  .compare_error                       (axi_08_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_8),
  .vio_tg_start                        (vio_tg_start_8),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_8),
  .vio_tg_err_clear                    (vio_tg_err_clear_8),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_8),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_8),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_8),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_8),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_8),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_8),
  .vio_tg_restart                      (vio_tg_restart_8),
  .vio_tg_pause                        (vio_tg_pause_8),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_8),
  .vio_tg_err_continue                 (vio_tg_err_continue_8),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_8),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_8),
  .vio_tg_instr_num                    (vio_tg_instr_num_8),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_8),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_8),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_8),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_8),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_8),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_8),
  .vio_tg_seed_num                     (vio_tg_seed_num_8),
  .vio_tg_seed                         (vio_tg_seed_8),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_8),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_8),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_8),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_8),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_8),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_8),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_8),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_8),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_8),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_8),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_8),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_8),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_8),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_8),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_8),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_8),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_8),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_8),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_8),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_8),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_8),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_8),
  .vio_tg_status_err_type              (vio_tg_status_err_type_8),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_8),
  .vio_tg_status_done                  (boot_mode_done_8),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_8),
  .tg_ila_debug                        (tg_ila_debug_8),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_08_AWID    = axi4_hbm_chs_li[8].awid;
  assign AXI_08_AWADDR  = axi4_hbm_chs_li[8].awaddr[0][32:0];
  assign AXI_08_AWLEN   = axi4_hbm_chs_li[8].awlen;
  assign AXI_08_AWSIZE  = axi4_hbm_chs_li[8].awsize;
  assign AXI_08_AWBURST = axi4_hbm_chs_li[8].awburst;
  // assign AXI_08_awlock = axi4_hbm_chs_li[8].awlock;
  assign AXI_08_AWCACHE = axi4_hbm_chs_li[8].awcache;
  assign AXI_08_AWPROT  = axi4_hbm_chs_li[8].awprot;
  assign AXI_08_AWVALID = axi4_hbm_chs_li[8].awvalid;
  assign AXI_08_WDATA   = axi4_hbm_chs_li[8].wdata;
  assign AXI_08_WSTRB   = axi4_hbm_chs_li[8].wstrb;
  assign AXI_08_WLAST   = axi4_hbm_chs_li[8].wlast;
  assign AXI_08_WVALID  = axi4_hbm_chs_li[8].wvalid;
  assign AXI_08_BREADY  = axi4_hbm_chs_li[8].bready;
  assign AXI_08_ARID    = axi4_hbm_chs_li[8].arid;
  assign AXI_08_ARADDR  = axi4_hbm_chs_li[8].araddr[0][32:0];
  assign AXI_08_ARLEN   = axi4_hbm_chs_li[8].arlen;
  assign AXI_08_ARSIZE  = axi4_hbm_chs_li[8].arsize;
  assign AXI_08_ARBURST = axi4_hbm_chs_li[8].arburst;
  // assign ( = axi4_hbm_chs_li[8].arburst;
  assign AXI_08_ARCACHE = axi4_hbm_chs_li[8].arcache;
  // assign ( = axi4_hbm_chs_li[8].arprot;
  assign AXI_08_ARVALID = axi4_hbm_chs_li[8].arvalid;
  assign AXI_08_RREADY  = axi4_hbm_chs_li[8].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[8].awready = AXI_08_AWREADY;
  assign axi4_hbm_chs_lo[8].wready  = AXI_08_WREADY;
  assign axi4_hbm_chs_lo[8].bid     = AXI_08_BID;
  assign axi4_hbm_chs_lo[8].bresp   = AXI_08_BRESP;
  assign axi4_hbm_chs_lo[8].bvalid  = AXI_08_BVALID;
  assign axi4_hbm_chs_lo[8].arready = AXI_08_ARREADY;
  assign axi4_hbm_chs_lo[8].rid     = AXI_08_RID;
  assign axi4_hbm_chs_lo[8].rresp   = AXI_08_RRESP;
  assign axi4_hbm_chs_lo[8].rvalid  = AXI_08_RVALID;
  assign axi4_hbm_chs_lo[8].rdata   = AXI_08_RDATA;
  assign axi4_hbm_chs_lo[8].rlast   = AXI_08_RLAST;



assign  vio_tg_rst_8 =  1'd0;
assign  i_force_vio_tg_status_done_8 = 16'h0000;
assign  i_vio_enable_atg_axi_x_8 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_8 =  16'hffff;
assign  vio_tg_restart_8 =  'd0;
assign  vio_tg_pause_8 =  'd0;
assign  vio_tg_err_chk_en_8 =  'd0;
assign  vio_tg_err_clear_8 =  'd0;
assign  vio_tg_err_clear_all_8 =  'd0;
assign  vio_tg_err_continue_8 =  'd0;
assign  vio_tg_instr_program_en_8 =  'd0;
assign  vio_tg_direct_instr_en_8 =  'd0;
assign  vio_tg_instr_num_8 =  'd0;
assign  vio_tg_instr_addr_mode_8 =  'd0;
assign  vio_tg_instr_data_mode_8 =  'd0;
assign  vio_tg_instr_rw_mode_8 =  'd0;
assign  vio_tg_instr_rw_submode_8 =  'd0;
assign  vio_tg_instr_victim_mode_8 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_8 =  'd0;
assign  vio_tg_instr_victim_select_8 =  'd0;
assign  vio_tg_instr_num_of_iter_8 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_8 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_8 =  'd0;
assign  vio_tg_instr_nxt_instr_8 =  'd0;
assign  vio_tg_seed_program_en_8 =  'd0;
assign  vio_tg_seed_num_8 =  'd0;
assign  vio_tg_seed_8 =  'd0;
assign  vio_tg_glb_start_addr_8 = 33'h0_8800_0000;

always@(posedge AXI_ACLK4_st0_buf or negedge axi_rst4_st0_n) begin
  if (~axi_rst4_st0_n) begin
    rd_cnt_08 <= 5'b0;
  end else if (AXI_08_RVALID && AXI_08_RREADY) begin
    rd_cnt_08 <= rd_cnt_08 + 1'b1;
  end
end

always@(posedge AXI_ACLK4_st0_buf or negedge axi_rst4_st0_n) begin
  if (~axi_rst4_st0_n) begin
    wr_cnt_08 <= 5'b0;
  end else if (AXI_08_BVALID && AXI_08_BREADY) begin
    wr_cnt_08 <= wr_cnt_08 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 8
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (8)
) u_axi_pmon_8 (
  .axi_arst_n              (axi_rst4_st0_n    ),
  .axi_aclk                (AXI_ACLK4_st0_buf ),
  .axi_awid                (AXI_08_AWID),
  .axi_awaddr              (AXI_08_AWADDR),
  .axi_awlen               (AXI_08_AWLEN),
  .axi_awsize              (AXI_08_AWSIZE),
  .axi_awburst             (AXI_08_AWBURST),
  .axi_awcache             (AXI_08_AWCACHE),
  .axi_awprot              (AXI_08_AWPROT),
  .axi_awvalid             (AXI_08_AWVALID),
  .axi_awready             (AXI_08_AWREADY),
  .axi_wdata               (AXI_08_WDATA),
  .axi_wstrb               (AXI_08_WSTRB),
  .axi_wlast               (AXI_08_WLAST),
  .axi_wvalid              (AXI_08_WVALID),
  .axi_wready              (AXI_08_WREADY),
  .axi_bready              (AXI_08_BREADY),
  .axi_bid                 (AXI_08_BID),
  .axi_bresp               (AXI_08_BRESP),
  .axi_bvalid              (AXI_08_BVALID),
  .axi_arid                (AXI_08_ARID),
  .axi_araddr              (AXI_08_ARADDR),
  .axi_arlen               (AXI_08_ARLEN),
  .axi_arsize              (AXI_08_ARSIZE),
  .axi_arburst             (AXI_08_ARBURST),
  .axi_arcache             (AXI_08_ARCACHE),
  .axi_arvalid             (AXI_08_ARVALID),
  .axi_arready             (AXI_08_ARREADY),
  .axi_rready              (AXI_08_RREADY),
  .axi_rid                 (AXI_08_RID),
  .axi_rdata               (AXI_08_RDATA),
  .axi_rresp               (AXI_08_RRESP),
  .axi_rlast               (AXI_08_RLAST),
  .axi_rvalid              (AXI_08_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 9
////////////////////////////////////////////////////////////////////////////////
// assign AXI_09_ARADDR = {vio_tg_glb_start_addr_9[32:28],o_m_axi_araddr_9[27:0]};
// assign AXI_09_AWADDR = {vio_tg_glb_start_addr_9[32:28],o_m_axi_awaddr_9[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_9 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK4_st0_buf),
  .i_rst                               (~axi_rst4_st0_n),
  .i_init_calib_complete               (apb_seq_complete_4_st0_r2),
  .compare_error                       (axi_09_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_9),
  .vio_tg_start                        (vio_tg_start_9),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_9),
  .vio_tg_err_clear                    (vio_tg_err_clear_9),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_9),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_9),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_9),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_9),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_9),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_9),
  .vio_tg_restart                      (vio_tg_restart_9),
  .vio_tg_pause                        (vio_tg_pause_9),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_9),
  .vio_tg_err_continue                 (vio_tg_err_continue_9),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_9),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_9),
  .vio_tg_instr_num                    (vio_tg_instr_num_9),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_9),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_9),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_9),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_9),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_9),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_9),
  .vio_tg_seed_num                     (vio_tg_seed_num_9),
  .vio_tg_seed                         (vio_tg_seed_9),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_9),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_9),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_9),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_9),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_9),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_9),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_9),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_9),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_9),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_9),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_9),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_9),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_9),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_9),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_9),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_9),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_9),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_9),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_9),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_9),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_9),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_9),
  .vio_tg_status_err_type              (vio_tg_status_err_type_9),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_9),
  .vio_tg_status_done                  (boot_mode_done_9),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_9),
  .tg_ila_debug                        (tg_ila_debug_9),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_09_AWID    = axi4_hbm_chs_li[9].awid;
  assign AXI_09_AWADDR  = axi4_hbm_chs_li[9].awaddr[0][32:0];
  assign AXI_09_AWLEN   = axi4_hbm_chs_li[9].awlen;
  assign AXI_09_AWSIZE  = axi4_hbm_chs_li[9].awsize;
  assign AXI_09_AWBURST = axi4_hbm_chs_li[9].awburst;
  // assign AXI_09_awlock = axi4_hbm_chs_li[9].awlock;
  assign AXI_09_AWCACHE = axi4_hbm_chs_li[9].awcache;
  assign AXI_09_AWPROT  = axi4_hbm_chs_li[9].awprot;
  assign AXI_09_AWVALID = axi4_hbm_chs_li[9].awvalid;
  assign AXI_09_WDATA   = axi4_hbm_chs_li[9].wdata;
  assign AXI_09_WSTRB   = axi4_hbm_chs_li[9].wstrb;
  assign AXI_09_WLAST   = axi4_hbm_chs_li[9].wlast;
  assign AXI_09_WVALID  = axi4_hbm_chs_li[9].wvalid;
  assign AXI_09_BREADY  = axi4_hbm_chs_li[9].bready;
  assign AXI_09_ARID    = axi4_hbm_chs_li[9].arid;
  assign AXI_09_ARADDR  = axi4_hbm_chs_li[9].araddr[0][32:0];
  assign AXI_09_ARLEN   = axi4_hbm_chs_li[9].arlen;
  assign AXI_09_ARSIZE  = axi4_hbm_chs_li[9].arsize;
  assign AXI_09_ARBURST = axi4_hbm_chs_li[9].arburst;
  // assign ( = axi4_hbm_chs_li[9].arburst;
  assign AXI_09_ARCACHE = axi4_hbm_chs_li[9].arcache;
  // assign ( = axi4_hbm_chs_li[9].arprot;
  assign AXI_09_ARVALID = axi4_hbm_chs_li[9].arvalid;
  assign AXI_09_RREADY  = axi4_hbm_chs_li[9].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[9].awready = AXI_09_AWREADY;
  assign axi4_hbm_chs_lo[9].wready  = AXI_09_WREADY;
  assign axi4_hbm_chs_lo[9].bid     = AXI_09_BID;
  assign axi4_hbm_chs_lo[9].bresp   = AXI_09_BRESP;
  assign axi4_hbm_chs_lo[9].bvalid  = AXI_09_BVALID;
  assign axi4_hbm_chs_lo[9].arready = AXI_09_ARREADY;
  assign axi4_hbm_chs_lo[9].rid     = AXI_09_RID;
  assign axi4_hbm_chs_lo[9].rresp   = AXI_09_RRESP;
  assign axi4_hbm_chs_lo[9].rvalid  = AXI_09_RVALID;
  assign axi4_hbm_chs_lo[9].rdata   = AXI_09_RDATA;
  assign axi4_hbm_chs_lo[9].rlast   = AXI_09_RLAST;



assign  vio_tg_rst_9 =  1'd0;
assign  i_force_vio_tg_status_done_9 = 16'h0000;
assign  i_vio_enable_atg_axi_x_9 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_9 =  16'hffff;
assign  vio_tg_restart_9 =  'd0;
assign  vio_tg_pause_9 =  'd0;
assign  vio_tg_err_chk_en_9 =  'd0;
assign  vio_tg_err_clear_9 =  'd0;
assign  vio_tg_err_clear_all_9 =  'd0;
assign  vio_tg_err_continue_9 =  'd0;
assign  vio_tg_instr_program_en_9 =  'd0;
assign  vio_tg_direct_instr_en_9 =  'd0;
assign  vio_tg_instr_num_9 =  'd0;
assign  vio_tg_instr_addr_mode_9 =  'd0;
assign  vio_tg_instr_data_mode_9 =  'd0;
assign  vio_tg_instr_rw_mode_9 =  'd0;
assign  vio_tg_instr_rw_submode_9 =  'd0;
assign  vio_tg_instr_victim_mode_9 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_9 =  'd0;
assign  vio_tg_instr_victim_select_9 =  'd0;
assign  vio_tg_instr_num_of_iter_9 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_9 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_9 =  'd0;
assign  vio_tg_instr_nxt_instr_9 =  'd0;
assign  vio_tg_seed_program_en_9 =  'd0;
assign  vio_tg_seed_num_9 =  'd0;
assign  vio_tg_seed_9 =  'd0;
assign  vio_tg_glb_start_addr_9 = 33'h0_9900_0000;

always@(posedge AXI_ACLK4_st0_buf or negedge axi_rst4_st0_n) begin
  if (~axi_rst4_st0_n) begin
    rd_cnt_09 <= 5'b0;
  end else if (AXI_09_RVALID && AXI_09_RREADY) begin
    rd_cnt_09 <= rd_cnt_09 + 1'b1;
  end
end

always@(posedge AXI_ACLK4_st0_buf or negedge axi_rst4_st0_n) begin
  if (~axi_rst4_st0_n) begin
    wr_cnt_09 <= 5'b0;
  end else if (AXI_09_BVALID && AXI_09_BREADY) begin
    wr_cnt_09 <= wr_cnt_09 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 9
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (9)
) u_axi_pmon_9 (
  .axi_arst_n              (axi_rst4_st0_n    ),
  .axi_aclk                (AXI_ACLK4_st0_buf ),
  .axi_awid                (AXI_09_AWID),
  .axi_awaddr              (AXI_09_AWADDR),
  .axi_awlen               (AXI_09_AWLEN),
  .axi_awsize              (AXI_09_AWSIZE),
  .axi_awburst             (AXI_09_AWBURST),
  .axi_awcache             (AXI_09_AWCACHE),
  .axi_awprot              (AXI_09_AWPROT),
  .axi_awvalid             (AXI_09_AWVALID),
  .axi_awready             (AXI_09_AWREADY),
  .axi_wdata               (AXI_09_WDATA),
  .axi_wstrb               (AXI_09_WSTRB),
  .axi_wlast               (AXI_09_WLAST),
  .axi_wvalid              (AXI_09_WVALID),
  .axi_wready              (AXI_09_WREADY),
  .axi_bready              (AXI_09_BREADY),
  .axi_bid                 (AXI_09_BID),
  .axi_bresp               (AXI_09_BRESP),
  .axi_bvalid              (AXI_09_BVALID),
  .axi_arid                (AXI_09_ARID),
  .axi_araddr              (AXI_09_ARADDR),
  .axi_arlen               (AXI_09_ARLEN),
  .axi_arsize              (AXI_09_ARSIZE),
  .axi_arburst             (AXI_09_ARBURST),
  .axi_arcache             (AXI_09_ARCACHE),
  .axi_arvalid             (AXI_09_ARVALID),
  .axi_arready             (AXI_09_ARREADY),
  .axi_rready              (AXI_09_RREADY),
  .axi_rid                 (AXI_09_RID),
  .axi_rdata               (AXI_09_RDATA),
  .axi_rresp               (AXI_09_RRESP),
  .axi_rlast               (AXI_09_RLAST),
  .axi_rvalid              (AXI_09_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 10
////////////////////////////////////////////////////////////////////////////////
// assign AXI_10_ARADDR = {vio_tg_glb_start_addr_10[32:28],o_m_axi_araddr_10[27:0]};
// assign AXI_10_AWADDR = {vio_tg_glb_start_addr_10[32:28],o_m_axi_awaddr_10[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_10 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK5_st0_buf),
  .i_rst                               (~axi_rst5_st0_n),
  .i_init_calib_complete               (apb_seq_complete_5_st0_r2),
  .compare_error                       (axi_10_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_10),
  .vio_tg_start                        (vio_tg_start_10),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_10),
  .vio_tg_err_clear                    (vio_tg_err_clear_10),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_10),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_10),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_10),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_10),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_10),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_10),
  .vio_tg_restart                      (vio_tg_restart_10),
  .vio_tg_pause                        (vio_tg_pause_10),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_10),
  .vio_tg_err_continue                 (vio_tg_err_continue_10),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_10),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_10),
  .vio_tg_instr_num                    (vio_tg_instr_num_10),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_10),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_10),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_10),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_10),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_10),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_10),
  .vio_tg_seed_num                     (vio_tg_seed_num_10),
  .vio_tg_seed                         (vio_tg_seed_10),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_10),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_10),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_10),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_10),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_10),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_10),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_10),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_10),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_10),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_10),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_10),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_10),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_10),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_10),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_10),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_10),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_10),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_10),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_10),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_10),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_10),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_10),
  .vio_tg_status_err_type              (vio_tg_status_err_type_10),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_10),
  .vio_tg_status_done                  (boot_mode_done_10),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_10),
  .tg_ila_debug                        (tg_ila_debug_10),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_10_AWID    = axi4_hbm_chs_li[10].awid;
  assign AXI_10_AWADDR  = axi4_hbm_chs_li[10].awaddr[0][32:0];
  assign AXI_10_AWLEN   = axi4_hbm_chs_li[10].awlen;
  assign AXI_10_AWSIZE  = axi4_hbm_chs_li[10].awsize;
  assign AXI_10_AWBURST = axi4_hbm_chs_li[10].awburst;
  // assign AXI_10_awlock = axi4_hbm_chs_li[10].awlock;
  assign AXI_10_AWCACHE = axi4_hbm_chs_li[10].awcache;
  assign AXI_10_AWPROT  = axi4_hbm_chs_li[10].awprot;
  assign AXI_10_AWVALID = axi4_hbm_chs_li[10].awvalid;
  assign AXI_10_WDATA   = axi4_hbm_chs_li[10].wdata;
  assign AXI_10_WSTRB   = axi4_hbm_chs_li[10].wstrb;
  assign AXI_10_WLAST   = axi4_hbm_chs_li[10].wlast;
  assign AXI_10_WVALID  = axi4_hbm_chs_li[10].wvalid;
  assign AXI_10_BREADY  = axi4_hbm_chs_li[10].bready;
  assign AXI_10_ARID    = axi4_hbm_chs_li[10].arid;
  assign AXI_10_ARADDR  = axi4_hbm_chs_li[10].araddr[0][32:0];
  assign AXI_10_ARLEN   = axi4_hbm_chs_li[10].arlen;
  assign AXI_10_ARSIZE  = axi4_hbm_chs_li[10].arsize;
  assign AXI_10_ARBURST = axi4_hbm_chs_li[10].arburst;
  // assign ( = axi4_hbm_chs_li[10].arburst;
  assign AXI_10_ARCACHE = axi4_hbm_chs_li[10].arcache;
  // assign ( = axi4_hbm_chs_li[10].arprot;
  assign AXI_10_ARVALID = axi4_hbm_chs_li[10].arvalid;
  assign AXI_10_RREADY  = axi4_hbm_chs_li[10].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[10].awready = AXI_10_AWREADY;
  assign axi4_hbm_chs_lo[10].wready  = AXI_10_WREADY;
  assign axi4_hbm_chs_lo[10].bid     = AXI_10_BID;
  assign axi4_hbm_chs_lo[10].bresp   = AXI_10_BRESP;
  assign axi4_hbm_chs_lo[10].bvalid  = AXI_10_BVALID;
  assign axi4_hbm_chs_lo[10].arready = AXI_10_ARREADY;
  assign axi4_hbm_chs_lo[10].rid     = AXI_10_RID;
  assign axi4_hbm_chs_lo[10].rresp   = AXI_10_RRESP;
  assign axi4_hbm_chs_lo[10].rvalid  = AXI_10_RVALID;
  assign axi4_hbm_chs_lo[10].rdata   = AXI_10_RDATA;
  assign axi4_hbm_chs_lo[10].rlast   = AXI_10_RLAST;



assign  vio_tg_rst_10 =  1'd0;
assign  i_force_vio_tg_status_done_10 = 16'h0000;
assign  i_vio_enable_atg_axi_x_10 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_10 =  16'hffff;
assign  vio_tg_restart_10 =  'd0;
assign  vio_tg_pause_10 =  'd0;
assign  vio_tg_err_chk_en_10 =  'd0;
assign  vio_tg_err_clear_10 =  'd0;
assign  vio_tg_err_clear_all_10 =  'd0;
assign  vio_tg_err_continue_10 =  'd0;
assign  vio_tg_instr_program_en_10 =  'd0;
assign  vio_tg_direct_instr_en_10 =  'd0;
assign  vio_tg_instr_num_10 =  'd0;
assign  vio_tg_instr_addr_mode_10 =  'd0;
assign  vio_tg_instr_data_mode_10 =  'd0;
assign  vio_tg_instr_rw_mode_10 =  'd0;
assign  vio_tg_instr_rw_submode_10 =  'd0;
assign  vio_tg_instr_victim_mode_10 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_10 =  'd0;
assign  vio_tg_instr_victim_select_10 =  'd0;
assign  vio_tg_instr_num_of_iter_10 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_10 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_10 =  'd0;
assign  vio_tg_instr_nxt_instr_10 =  'd0;
assign  vio_tg_seed_program_en_10 =  'd0;
assign  vio_tg_seed_num_10 =  'd0;
assign  vio_tg_seed_10 =  'd0;
assign  vio_tg_glb_start_addr_10 = 33'h0_AA00_0000;

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    rd_cnt_10 <= 5'b0;
  end else if (AXI_10_RVALID && AXI_10_RREADY) begin
    rd_cnt_10 <= rd_cnt_10 + 1'b1;
  end
end

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    wr_cnt_10 <= 5'b0;
  end else if (AXI_10_BVALID && AXI_10_BREADY) begin
    wr_cnt_10 <= wr_cnt_10 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 10
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (10)
) u_axi_pmon_10 (
  .axi_arst_n              (axi_rst5_st0_n    ),
  .axi_aclk                (AXI_ACLK5_st0_buf ),
  .axi_awid                (AXI_10_AWID),
  .axi_awaddr              (AXI_10_AWADDR),
  .axi_awlen               (AXI_10_AWLEN),
  .axi_awsize              (AXI_10_AWSIZE),
  .axi_awburst             (AXI_10_AWBURST),
  .axi_awcache             (AXI_10_AWCACHE),
  .axi_awprot              (AXI_10_AWPROT),
  .axi_awvalid             (AXI_10_AWVALID),
  .axi_awready             (AXI_10_AWREADY),
  .axi_wdata               (AXI_10_WDATA),
  .axi_wstrb               (AXI_10_WSTRB),
  .axi_wlast               (AXI_10_WLAST),
  .axi_wvalid              (AXI_10_WVALID),
  .axi_wready              (AXI_10_WREADY),
  .axi_bready              (AXI_10_BREADY),
  .axi_bid                 (AXI_10_BID),
  .axi_bresp               (AXI_10_BRESP),
  .axi_bvalid              (AXI_10_BVALID),
  .axi_arid                (AXI_10_ARID),
  .axi_araddr              (AXI_10_ARADDR),
  .axi_arlen               (AXI_10_ARLEN),
  .axi_arsize              (AXI_10_ARSIZE),
  .axi_arburst             (AXI_10_ARBURST),
  .axi_arcache             (AXI_10_ARCACHE),
  .axi_arvalid             (AXI_10_ARVALID),
  .axi_arready             (AXI_10_ARREADY),
  .axi_rready              (AXI_10_RREADY),
  .axi_rid                 (AXI_10_RID),
  .axi_rdata               (AXI_10_RDATA),
  .axi_rresp               (AXI_10_RRESP),
  .axi_rlast               (AXI_10_RLAST),
  .axi_rvalid              (AXI_10_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 11
////////////////////////////////////////////////////////////////////////////////
// assign AXI_11_ARADDR = {vio_tg_glb_start_addr_11[32:28],o_m_axi_araddr_11[27:0]};
// assign AXI_11_AWADDR = {vio_tg_glb_start_addr_11[32:28],o_m_axi_awaddr_11[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_11 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK5_st0_buf),
  .i_rst                               (~axi_rst5_st0_n),
  .i_init_calib_complete               (apb_seq_complete_5_st0_r2),
  .compare_error                       (axi_11_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_11),
  .vio_tg_start                        (vio_tg_start_11),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_11),
  .vio_tg_err_clear                    (vio_tg_err_clear_11),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_11),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_11),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_11),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_11),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_11),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_11),
  .vio_tg_restart                      (vio_tg_restart_11),
  .vio_tg_pause                        (vio_tg_pause_11),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_11),
  .vio_tg_err_continue                 (vio_tg_err_continue_11),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_11),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_11),
  .vio_tg_instr_num                    (vio_tg_instr_num_11),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_11),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_11),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_11),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_11),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_11),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_11),
  .vio_tg_seed_num                     (vio_tg_seed_num_11),
  .vio_tg_seed                         (vio_tg_seed_11),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_11),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_11),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_11),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_11),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_11),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_11),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_11),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_11),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_11),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_11),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_11),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_11),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_11),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_11),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_11),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_11),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_11),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_11),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_11),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_11),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_11),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_11),
  .vio_tg_status_err_type              (vio_tg_status_err_type_11),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_11),
  .vio_tg_status_done                  (boot_mode_done_11),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_11),
  .tg_ila_debug                        (tg_ila_debug_11),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_11_AWID    = axi4_hbm_chs_li[11].awid;
  assign AXI_11_AWADDR  = axi4_hbm_chs_li[11].awaddr[0][32:0];
  assign AXI_11_AWLEN   = axi4_hbm_chs_li[11].awlen;
  assign AXI_11_AWSIZE  = axi4_hbm_chs_li[11].awsize;
  assign AXI_11_AWBURST = axi4_hbm_chs_li[11].awburst;
  // assign AXI_11_awlock = axi4_hbm_chs_li[11].awlock;
  assign AXI_11_AWCACHE = axi4_hbm_chs_li[11].awcache;
  assign AXI_11_AWPROT  = axi4_hbm_chs_li[11].awprot;
  assign AXI_11_AWVALID = axi4_hbm_chs_li[11].awvalid;
  assign AXI_11_WDATA   = axi4_hbm_chs_li[11].wdata;
  assign AXI_11_WSTRB   = axi4_hbm_chs_li[11].wstrb;
  assign AXI_11_WLAST   = axi4_hbm_chs_li[11].wlast;
  assign AXI_11_WVALID  = axi4_hbm_chs_li[11].wvalid;
  assign AXI_11_BREADY  = axi4_hbm_chs_li[11].bready;
  assign AXI_11_ARID    = axi4_hbm_chs_li[11].arid;
  assign AXI_11_ARADDR  = axi4_hbm_chs_li[11].araddr[0][32:0];
  assign AXI_11_ARLEN   = axi4_hbm_chs_li[11].arlen;
  assign AXI_11_ARSIZE  = axi4_hbm_chs_li[11].arsize;
  assign AXI_11_ARBURST = axi4_hbm_chs_li[11].arburst;
  // assign ( = axi4_hbm_chs_li[11].arburst;
  assign AXI_11_ARCACHE = axi4_hbm_chs_li[11].arcache;
  // assign ( = axi4_hbm_chs_li[11].arprot;
  assign AXI_11_ARVALID = axi4_hbm_chs_li[11].arvalid;
  assign AXI_11_RREADY  = axi4_hbm_chs_li[11].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[11].awready = AXI_11_AWREADY;
  assign axi4_hbm_chs_lo[11].wready  = AXI_11_WREADY;
  assign axi4_hbm_chs_lo[11].bid     = AXI_11_BID;
  assign axi4_hbm_chs_lo[11].bresp   = AXI_11_BRESP;
  assign axi4_hbm_chs_lo[11].bvalid  = AXI_11_BVALID;
  assign axi4_hbm_chs_lo[11].arready = AXI_11_ARREADY;
  assign axi4_hbm_chs_lo[11].rid     = AXI_11_RID;
  assign axi4_hbm_chs_lo[11].rresp   = AXI_11_RRESP;
  assign axi4_hbm_chs_lo[11].rvalid  = AXI_11_RVALID;
  assign axi4_hbm_chs_lo[11].rdata   = AXI_11_RDATA;
  assign axi4_hbm_chs_lo[11].rlast   = AXI_11_RLAST;


assign  vio_tg_rst_11 =  1'd0;
assign  i_force_vio_tg_status_done_11 = 16'h0000;
assign  i_vio_enable_atg_axi_x_11 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_11 =  16'hffff;
assign  vio_tg_restart_11 =  'd0;
assign  vio_tg_pause_11 =  'd0;
assign  vio_tg_err_chk_en_11 =  'd0;
assign  vio_tg_err_clear_11 =  'd0;
assign  vio_tg_err_clear_all_11 =  'd0;
assign  vio_tg_err_continue_11 =  'd0;
assign  vio_tg_instr_program_en_11 =  'd0;
assign  vio_tg_direct_instr_en_11 =  'd0;
assign  vio_tg_instr_num_11 =  'd0;
assign  vio_tg_instr_addr_mode_11 =  'd0;
assign  vio_tg_instr_data_mode_11 =  'd0;
assign  vio_tg_instr_rw_mode_11 =  'd0;
assign  vio_tg_instr_rw_submode_11 =  'd0;
assign  vio_tg_instr_victim_mode_11 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_11 =  'd0;
assign  vio_tg_instr_victim_select_11 =  'd0;
assign  vio_tg_instr_num_of_iter_11 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_11 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_11 =  'd0;
assign  vio_tg_instr_nxt_instr_11 =  'd0;
assign  vio_tg_seed_program_en_11 =  'd0;
assign  vio_tg_seed_num_11 =  'd0;
assign  vio_tg_seed_11 =  'd0;
assign  vio_tg_glb_start_addr_11 = 33'h0_BB00_0000;

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    rd_cnt_11 <= 5'b0;
  end else if (AXI_11_RVALID && AXI_11_RREADY) begin
    rd_cnt_11 <= rd_cnt_11 + 1'b1;
  end
end

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    wr_cnt_11 <= 5'b0;
  end else if (AXI_11_BVALID && AXI_11_BREADY) begin
    wr_cnt_11 <= wr_cnt_11 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 11
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (11)
) u_axi_pmon_11 (
  .axi_arst_n              (axi_rst5_st0_n    ),
  .axi_aclk                (AXI_ACLK5_st0_buf ),
  .axi_awid                (AXI_11_AWID),
  .axi_awaddr              (AXI_11_AWADDR),
  .axi_awlen               (AXI_11_AWLEN),
  .axi_awsize              (AXI_11_AWSIZE),
  .axi_awburst             (AXI_11_AWBURST),
  .axi_awcache             (AXI_11_AWCACHE),
  .axi_awprot              (AXI_11_AWPROT),
  .axi_awvalid             (AXI_11_AWVALID),
  .axi_awready             (AXI_11_AWREADY),
  .axi_wdata               (AXI_11_WDATA),
  .axi_wstrb               (AXI_11_WSTRB),
  .axi_wlast               (AXI_11_WLAST),
  .axi_wvalid              (AXI_11_WVALID),
  .axi_wready              (AXI_11_WREADY),
  .axi_bready              (AXI_11_BREADY),
  .axi_bid                 (AXI_11_BID),
  .axi_bresp               (AXI_11_BRESP),
  .axi_bvalid              (AXI_11_BVALID),
  .axi_arid                (AXI_11_ARID),
  .axi_araddr              (AXI_11_ARADDR),
  .axi_arlen               (AXI_11_ARLEN),
  .axi_arsize              (AXI_11_ARSIZE),
  .axi_arburst             (AXI_11_ARBURST),
  .axi_arcache             (AXI_11_ARCACHE),
  .axi_arvalid             (AXI_11_ARVALID),
  .axi_arready             (AXI_11_ARREADY),
  .axi_rready              (AXI_11_RREADY),
  .axi_rid                 (AXI_11_RID),
  .axi_rdata               (AXI_11_RDATA),
  .axi_rresp               (AXI_11_RRESP),
  .axi_rlast               (AXI_11_RLAST),
  .axi_rvalid              (AXI_11_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 12
////////////////////////////////////////////////////////////////////////////////
// assign AXI_12_ARADDR = {vio_tg_glb_start_addr_12[32:28],o_m_axi_araddr_12[27:0]};
// assign AXI_12_AWADDR = {vio_tg_glb_start_addr_12[32:28],o_m_axi_awaddr_12[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_12 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK5_st0_buf),
  .i_rst                               (~axi_rst5_st0_n),
  .i_init_calib_complete               (apb_seq_complete_5_st0_r2),
  .compare_error                       (axi_12_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_12),
  .vio_tg_start                        (vio_tg_start_12),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_12),
  .vio_tg_err_clear                    (vio_tg_err_clear_12),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_12),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_12),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_12),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_12),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_12),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_12),
  .vio_tg_restart                      (vio_tg_restart_12),
  .vio_tg_pause                        (vio_tg_pause_12),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_12),
  .vio_tg_err_continue                 (vio_tg_err_continue_12),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_12),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_12),
  .vio_tg_instr_num                    (vio_tg_instr_num_12),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_12),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_12),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_12),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_12),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_12),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_12),
  .vio_tg_seed_num                     (vio_tg_seed_num_12),
  .vio_tg_seed                         (vio_tg_seed_12),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_12),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_12),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_12),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_12),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_12),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_12),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_12),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_12),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_12),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_12),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_12),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_12),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_12),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_12),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_12),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_12),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_12),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_12),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_12),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_12),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_12),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_12),
  .vio_tg_status_err_type              (vio_tg_status_err_type_12),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_12),
  .vio_tg_status_done                  (boot_mode_done_12),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_12),
  .tg_ila_debug                        (tg_ila_debug_12),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_12_AWID    = axi4_hbm_chs_li[12].awid;
  assign AXI_12_AWADDR  = axi4_hbm_chs_li[12].awaddr[0][32:0];
  assign AXI_12_AWLEN   = axi4_hbm_chs_li[12].awlen;
  assign AXI_12_AWSIZE  = axi4_hbm_chs_li[12].awsize;
  assign AXI_12_AWBURST = axi4_hbm_chs_li[12].awburst;
  // assign AXI_12_awlock = axi4_hbm_chs_li[12].awlock;
  assign AXI_12_AWCACHE = axi4_hbm_chs_li[12].awcache;
  assign AXI_12_AWPROT  = axi4_hbm_chs_li[12].awprot;
  assign AXI_12_AWVALID = axi4_hbm_chs_li[12].awvalid;
  assign AXI_12_WDATA   = axi4_hbm_chs_li[12].wdata;
  assign AXI_12_WSTRB   = axi4_hbm_chs_li[12].wstrb;
  assign AXI_12_WLAST   = axi4_hbm_chs_li[12].wlast;
  assign AXI_12_WVALID  = axi4_hbm_chs_li[12].wvalid;
  assign AXI_12_BREADY  = axi4_hbm_chs_li[12].bready;
  assign AXI_12_ARID    = axi4_hbm_chs_li[12].arid;
  assign AXI_12_ARADDR  = axi4_hbm_chs_li[12].araddr[0][32:0];
  assign AXI_12_ARLEN   = axi4_hbm_chs_li[12].arlen;
  assign AXI_12_ARSIZE  = axi4_hbm_chs_li[12].arsize;
  assign AXI_12_ARBURST = axi4_hbm_chs_li[12].arburst;
  // assign ( = axi4_hbm_chs_li[12].arburst;
  assign AXI_12_ARCACHE = axi4_hbm_chs_li[12].arcache;
  // assign ( = axi4_hbm_chs_li[12].arprot;
  assign AXI_12_ARVALID = axi4_hbm_chs_li[12].arvalid;
  assign AXI_12_RREADY  = axi4_hbm_chs_li[12].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[12].awready = AXI_12_AWREADY;
  assign axi4_hbm_chs_lo[12].wready  = AXI_12_WREADY;
  assign axi4_hbm_chs_lo[12].bid     = AXI_12_BID;
  assign axi4_hbm_chs_lo[12].bresp   = AXI_12_BRESP;
  assign axi4_hbm_chs_lo[12].bvalid  = AXI_12_BVALID;
  assign axi4_hbm_chs_lo[12].arready = AXI_12_ARREADY;
  assign axi4_hbm_chs_lo[12].rid     = AXI_12_RID;
  assign axi4_hbm_chs_lo[12].rresp   = AXI_12_RRESP;
  assign axi4_hbm_chs_lo[12].rvalid  = AXI_12_RVALID;
  assign axi4_hbm_chs_lo[12].rdata   = AXI_12_RDATA;
  assign axi4_hbm_chs_lo[12].rlast   = AXI_12_RLAST;


assign  vio_tg_rst_12 =  1'd0;
assign  i_force_vio_tg_status_done_12 = 16'h0000;
assign  i_vio_enable_atg_axi_x_12 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_12 =  16'hffff;
assign  vio_tg_restart_12 =  'd0;
assign  vio_tg_pause_12 =  'd0;
assign  vio_tg_err_chk_en_12 =  'd0;
assign  vio_tg_err_clear_12 =  'd0;
assign  vio_tg_err_clear_all_12 =  'd0;
assign  vio_tg_err_continue_12 =  'd0;
assign  vio_tg_instr_program_en_12 =  'd0;
assign  vio_tg_direct_instr_en_12 =  'd0;
assign  vio_tg_instr_num_12 =  'd0;
assign  vio_tg_instr_addr_mode_12 =  'd0;
assign  vio_tg_instr_data_mode_12 =  'd0;
assign  vio_tg_instr_rw_mode_12 =  'd0;
assign  vio_tg_instr_rw_submode_12 =  'd0;
assign  vio_tg_instr_victim_mode_12 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_12 =  'd0;
assign  vio_tg_instr_victim_select_12 =  'd0;
assign  vio_tg_instr_num_of_iter_12 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_12 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_12 =  'd0;
assign  vio_tg_instr_nxt_instr_12 =  'd0;
assign  vio_tg_seed_program_en_12 =  'd0;
assign  vio_tg_seed_num_12 =  'd0;
assign  vio_tg_seed_12 =  'd0;
assign  vio_tg_glb_start_addr_12 = 33'h0_CC00_0000;

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    rd_cnt_12 <= 5'b0;
  end else if (AXI_12_RVALID && AXI_12_RREADY) begin
    rd_cnt_12 <= rd_cnt_12 + 1'b1;
  end
end

always@(posedge AXI_ACLK5_st0_buf or negedge axi_rst5_st0_n) begin
  if (~axi_rst5_st0_n) begin
    wr_cnt_12 <= 5'b0;
  end else if (AXI_12_BVALID && AXI_12_BREADY) begin
    wr_cnt_12 <= wr_cnt_12 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 12
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (12)
) u_axi_pmon_12 (
  .axi_arst_n              (axi_rst5_st0_n    ),
  .axi_aclk                (AXI_ACLK5_st0_buf),
  .axi_awid                (AXI_12_AWID),
  .axi_awaddr              (AXI_12_AWADDR),
  .axi_awlen               (AXI_12_AWLEN),
  .axi_awsize              (AXI_12_AWSIZE),
  .axi_awburst             (AXI_12_AWBURST),
  .axi_awcache             (AXI_12_AWCACHE),
  .axi_awprot              (AXI_12_AWPROT),
  .axi_awvalid             (AXI_12_AWVALID),
  .axi_awready             (AXI_12_AWREADY),
  .axi_wdata               (AXI_12_WDATA),
  .axi_wstrb               (AXI_12_WSTRB),
  .axi_wlast               (AXI_12_WLAST),
  .axi_wvalid              (AXI_12_WVALID),
  .axi_wready              (AXI_12_WREADY),
  .axi_bready              (AXI_12_BREADY),
  .axi_bid                 (AXI_12_BID),
  .axi_bresp               (AXI_12_BRESP),
  .axi_bvalid              (AXI_12_BVALID),
  .axi_arid                (AXI_12_ARID),
  .axi_araddr              (AXI_12_ARADDR),
  .axi_arlen               (AXI_12_ARLEN),
  .axi_arsize              (AXI_12_ARSIZE),
  .axi_arburst             (AXI_12_ARBURST),
  .axi_arcache             (AXI_12_ARCACHE),
  .axi_arvalid             (AXI_12_ARVALID),
  .axi_arready             (AXI_12_ARREADY),
  .axi_rready              (AXI_12_RREADY),
  .axi_rid                 (AXI_12_RID),
  .axi_rdata               (AXI_12_RDATA),
  .axi_rresp               (AXI_12_RRESP),
  .axi_rlast               (AXI_12_RLAST),
  .axi_rvalid              (AXI_12_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 13
////////////////////////////////////////////////////////////////////////////////
// assign AXI_13_ARADDR = {vio_tg_glb_start_addr_13[32:28],o_m_axi_araddr_13[27:0]};
// assign AXI_13_AWADDR = {vio_tg_glb_start_addr_13[32:28],o_m_axi_awaddr_13[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_13 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK6_st0_buf),
  .i_rst                               (~axi_rst6_st0_n),
  .i_init_calib_complete               (apb_seq_complete_6_st0_r2),
  .compare_error                       (axi_13_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_13),
  .vio_tg_start                        (vio_tg_start_13),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_13),
  .vio_tg_err_clear                    (vio_tg_err_clear_13),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_13),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_13),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_13),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_13),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_13),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_13),
  .vio_tg_restart                      (vio_tg_restart_13),
  .vio_tg_pause                        (vio_tg_pause_13),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_13),
  .vio_tg_err_continue                 (vio_tg_err_continue_13),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_13),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_13),
  .vio_tg_instr_num                    (vio_tg_instr_num_13),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_13),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_13),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_13),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_13),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_13),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_13),
  .vio_tg_seed_num                     (vio_tg_seed_num_13),
  .vio_tg_seed                         (vio_tg_seed_13),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_13),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_13),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_13),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_13),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_13),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_13),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_13),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_13),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_13),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_13),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_13),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_13),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_13),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_13),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_13),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_13),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_13),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_13),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_13),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_13),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_13),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_13),
  .vio_tg_status_err_type              (vio_tg_status_err_type_13),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_13),
  .vio_tg_status_done                  (boot_mode_done_13),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_13),
  .tg_ila_debug                        (tg_ila_debug_13),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_13_AWID    = axi4_hbm_chs_li[13].awid;
  assign AXI_13_AWADDR  = axi4_hbm_chs_li[13].awaddr[0][32:0];
  assign AXI_13_AWLEN   = axi4_hbm_chs_li[13].awlen;
  assign AXI_13_AWSIZE  = axi4_hbm_chs_li[13].awsize;
  assign AXI_13_AWBURST = axi4_hbm_chs_li[13].awburst;
  // assign AXI_13_awlock = axi4_hbm_chs_li[13].awlock;
  assign AXI_13_AWCACHE = axi4_hbm_chs_li[13].awcache;
  assign AXI_13_AWPROT  = axi4_hbm_chs_li[13].awprot;
  assign AXI_13_AWVALID = axi4_hbm_chs_li[13].awvalid;
  assign AXI_13_WDATA   = axi4_hbm_chs_li[13].wdata;
  assign AXI_13_WSTRB   = axi4_hbm_chs_li[13].wstrb;
  assign AXI_13_WLAST   = axi4_hbm_chs_li[13].wlast;
  assign AXI_13_WVALID  = axi4_hbm_chs_li[13].wvalid;
  assign AXI_13_BREADY  = axi4_hbm_chs_li[13].bready;
  assign AXI_13_ARID    = axi4_hbm_chs_li[13].arid;
  assign AXI_13_ARADDR  = axi4_hbm_chs_li[13].araddr[0][32:0];
  assign AXI_13_ARLEN   = axi4_hbm_chs_li[13].arlen;
  assign AXI_13_ARSIZE  = axi4_hbm_chs_li[13].arsize;
  assign AXI_13_ARBURST = axi4_hbm_chs_li[13].arburst;
  // assign ( = axi4_hbm_chs_li[13].arburst;
  assign AXI_13_ARCACHE = axi4_hbm_chs_li[13].arcache;
  // assign ( = axi4_hbm_chs_li[13].arprot;
  assign AXI_13_ARVALID = axi4_hbm_chs_li[13].arvalid;
  assign AXI_13_RREADY  = axi4_hbm_chs_li[13].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[13].awready = AXI_13_AWREADY;
  assign axi4_hbm_chs_lo[13].wready  = AXI_13_WREADY;
  assign axi4_hbm_chs_lo[13].bid     = AXI_13_BID;
  assign axi4_hbm_chs_lo[13].bresp   = AXI_13_BRESP;
  assign axi4_hbm_chs_lo[13].bvalid  = AXI_13_BVALID;
  assign axi4_hbm_chs_lo[13].arready = AXI_13_ARREADY;
  assign axi4_hbm_chs_lo[13].rid     = AXI_13_RID;
  assign axi4_hbm_chs_lo[13].rresp   = AXI_13_RRESP;
  assign axi4_hbm_chs_lo[13].rvalid  = AXI_13_RVALID;
  assign axi4_hbm_chs_lo[13].rdata   = AXI_13_RDATA;
  assign axi4_hbm_chs_lo[13].rlast   = AXI_13_RLAST;


assign  vio_tg_rst_13 =  1'd0;
assign  i_force_vio_tg_status_done_13 = 16'h0000;
assign  i_vio_enable_atg_axi_x_13 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_13 =  16'hffff;
assign  vio_tg_restart_13 =  'd0;
assign  vio_tg_pause_13 =  'd0;
assign  vio_tg_err_chk_en_13 =  'd0;
assign  vio_tg_err_clear_13 =  'd0;
assign  vio_tg_err_clear_all_13 =  'd0;
assign  vio_tg_err_continue_13 =  'd0;
assign  vio_tg_instr_program_en_13 =  'd0;
assign  vio_tg_direct_instr_en_13 =  'd0;
assign  vio_tg_instr_num_13 =  'd0;
assign  vio_tg_instr_addr_mode_13 =  'd0;
assign  vio_tg_instr_data_mode_13 =  'd0;
assign  vio_tg_instr_rw_mode_13 =  'd0;
assign  vio_tg_instr_rw_submode_13 =  'd0;
assign  vio_tg_instr_victim_mode_13 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_13 =  'd0;
assign  vio_tg_instr_victim_select_13 =  'd0;
assign  vio_tg_instr_num_of_iter_13 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_13 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_13 =  'd0;
assign  vio_tg_instr_nxt_instr_13 =  'd0;
assign  vio_tg_seed_program_en_13 =  'd0;
assign  vio_tg_seed_num_13 =  'd0;
assign  vio_tg_seed_13 =  'd0;
assign  vio_tg_glb_start_addr_13 = 33'h0_DD00_0000;

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    rd_cnt_13 <= 5'b0;
  end else if (AXI_13_RVALID && AXI_13_RREADY) begin
    rd_cnt_13 <= rd_cnt_13 + 1'b1;
  end
end

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    wr_cnt_13 <= 5'b0;
  end else if (AXI_13_BVALID && AXI_13_BREADY) begin
    wr_cnt_13 <= wr_cnt_13 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 13
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (13)
) u_axi_pmon_13 (
  .axi_arst_n              (axi_rst6_st0_n    ),
  .axi_aclk                (AXI_ACLK6_st0_buf ),
  .axi_awid                (AXI_13_AWID),
  .axi_awaddr              (AXI_13_AWADDR),
  .axi_awlen               (AXI_13_AWLEN),
  .axi_awsize              (AXI_13_AWSIZE),
  .axi_awburst             (AXI_13_AWBURST),
  .axi_awcache             (AXI_13_AWCACHE),
  .axi_awprot              (AXI_13_AWPROT),
  .axi_awvalid             (AXI_13_AWVALID),
  .axi_awready             (AXI_13_AWREADY),
  .axi_wdata               (AXI_13_WDATA),
  .axi_wstrb               (AXI_13_WSTRB),
  .axi_wlast               (AXI_13_WLAST),
  .axi_wvalid              (AXI_13_WVALID),
  .axi_wready              (AXI_13_WREADY),
  .axi_bready              (AXI_13_BREADY),
  .axi_bid                 (AXI_13_BID),
  .axi_bresp               (AXI_13_BRESP),
  .axi_bvalid              (AXI_13_BVALID),
  .axi_arid                (AXI_13_ARID),
  .axi_araddr              (AXI_13_ARADDR),
  .axi_arlen               (AXI_13_ARLEN),
  .axi_arsize              (AXI_13_ARSIZE),
  .axi_arburst             (AXI_13_ARBURST),
  .axi_arcache             (AXI_13_ARCACHE),
  .axi_arvalid             (AXI_13_ARVALID),
  .axi_arready             (AXI_13_ARREADY),
  .axi_rready              (AXI_13_RREADY),
  .axi_rid                 (AXI_13_RID),
  .axi_rdata               (AXI_13_RDATA),
  .axi_rresp               (AXI_13_RRESP),
  .axi_rlast               (AXI_13_RLAST),
  .axi_rvalid              (AXI_13_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 14
////////////////////////////////////////////////////////////////////////////////
// assign AXI_14_ARADDR = {vio_tg_glb_start_addr_14[32:28],o_m_axi_araddr_14[27:0]};
// assign AXI_14_AWADDR = {vio_tg_glb_start_addr_14[32:28],o_m_axi_awaddr_14[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_14 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK6_st0_buf),
  .i_rst                               (~axi_rst6_st0_n),
  .i_init_calib_complete               (apb_seq_complete_6_st0_r2),
  .compare_error                       (axi_14_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_14),
  .vio_tg_start                        (vio_tg_start_14),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_14),
  .vio_tg_err_clear                    (vio_tg_err_clear_14),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_14),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_14),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_14),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_14),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_14),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_14),
  .vio_tg_restart                      (vio_tg_restart_14),
  .vio_tg_pause                        (vio_tg_pause_14),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_14),
  .vio_tg_err_continue                 (vio_tg_err_continue_14),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_14),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_14),
  .vio_tg_instr_num                    (vio_tg_instr_num_14),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_14),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_14),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_14),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_14),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_14),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_14),
  .vio_tg_seed_num                     (vio_tg_seed_num_14),
  .vio_tg_seed                         (vio_tg_seed_14),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_14),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_14),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_14),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_14),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_14),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_14),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_14),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_14),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_14),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_14),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_14),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_14),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_14),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_14),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_14),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_14),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_14),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_14),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_14),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_14),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_14),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_14),
  .vio_tg_status_err_type              (vio_tg_status_err_type_14),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_14),
  .vio_tg_status_done                  (boot_mode_done_14),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_14),
  .tg_ila_debug                        (tg_ila_debug_14),
  .tg_qdriv_submode11_app_rd           (1'b0),
  // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_14_AWID    = axi4_hbm_chs_li[14].awid;
  assign AXI_14_AWADDR  = axi4_hbm_chs_li[14].awaddr[0][32:0];
  assign AXI_14_AWLEN   = axi4_hbm_chs_li[14].awlen;
  assign AXI_14_AWSIZE  = axi4_hbm_chs_li[14].awsize;
  assign AXI_14_AWBURST = axi4_hbm_chs_li[14].awburst;
  // assign AXI_14_awlock = axi4_hbm_chs_li[14].awlock;
  assign AXI_14_AWCACHE = axi4_hbm_chs_li[14].awcache;
  assign AXI_14_AWPROT  = axi4_hbm_chs_li[14].awprot;
  assign AXI_14_AWVALID = axi4_hbm_chs_li[14].awvalid;
  assign AXI_14_WDATA   = axi4_hbm_chs_li[14].wdata;
  assign AXI_14_WSTRB   = axi4_hbm_chs_li[14].wstrb;
  assign AXI_14_WLAST   = axi4_hbm_chs_li[14].wlast;
  assign AXI_14_WVALID  = axi4_hbm_chs_li[14].wvalid;
  assign AXI_14_BREADY  = axi4_hbm_chs_li[14].bready;
  assign AXI_14_ARID    = axi4_hbm_chs_li[14].arid;
  assign AXI_14_ARADDR  = axi4_hbm_chs_li[14].araddr[0][32:0];
  assign AXI_14_ARLEN   = axi4_hbm_chs_li[14].arlen;
  assign AXI_14_ARSIZE  = axi4_hbm_chs_li[14].arsize;
  assign AXI_14_ARBURST = axi4_hbm_chs_li[14].arburst;
  // assign ( = axi4_hbm_chs_li[14].arburst;
  assign AXI_14_ARCACHE = axi4_hbm_chs_li[14].arcache;
  // assign ( = axi4_hbm_chs_li[14].arprot;
  assign AXI_14_ARVALID = axi4_hbm_chs_li[14].arvalid;
  assign AXI_14_RREADY  = axi4_hbm_chs_li[14].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[14].awready = AXI_14_AWREADY;
  assign axi4_hbm_chs_lo[14].wready  = AXI_14_WREADY;
  assign axi4_hbm_chs_lo[14].bid     = AXI_14_BID;
  assign axi4_hbm_chs_lo[14].bresp   = AXI_14_BRESP;
  assign axi4_hbm_chs_lo[14].bvalid  = AXI_14_BVALID;
  assign axi4_hbm_chs_lo[14].arready = AXI_14_ARREADY;
  assign axi4_hbm_chs_lo[14].rid     = AXI_14_RID;
  assign axi4_hbm_chs_lo[14].rresp   = AXI_14_RRESP;
  assign axi4_hbm_chs_lo[14].rvalid  = AXI_14_RVALID;
  assign axi4_hbm_chs_lo[14].rdata   = AXI_14_RDATA;
  assign axi4_hbm_chs_lo[14].rlast   = AXI_14_RLAST;



assign  vio_tg_rst_14 =  1'd0;
assign  i_force_vio_tg_status_done_14 = 16'h0000;
assign  i_vio_enable_atg_axi_x_14 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_14 =  16'hffff;
assign  vio_tg_restart_14 =  'd0;
assign  vio_tg_pause_14 =  'd0;
assign  vio_tg_err_chk_en_14 =  'd0;
assign  vio_tg_err_clear_14 =  'd0;
assign  vio_tg_err_clear_all_14 =  'd0;
assign  vio_tg_err_continue_14 =  'd0;
assign  vio_tg_instr_program_en_14 =  'd0;
assign  vio_tg_direct_instr_en_14 =  'd0;
assign  vio_tg_instr_num_14 =  'd0;
assign  vio_tg_instr_addr_mode_14 =  'd0;
assign  vio_tg_instr_data_mode_14 =  'd0;
assign  vio_tg_instr_rw_mode_14 =  'd0;
assign  vio_tg_instr_rw_submode_14 =  'd0;
assign  vio_tg_instr_victim_mode_14 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_14 =  'd0;
assign  vio_tg_instr_victim_select_14 =  'd0;
assign  vio_tg_instr_num_of_iter_14 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_14 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_14 =  'd0;
assign  vio_tg_instr_nxt_instr_14 =  'd0;
assign  vio_tg_seed_program_en_14 =  'd0;
assign  vio_tg_seed_num_14 =  'd0;
assign  vio_tg_seed_14 =  'd0;
assign  vio_tg_glb_start_addr_14 = 33'h0_EE00_0000;

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    rd_cnt_14 <= 5'b0;
  end else if (AXI_14_RVALID && AXI_14_RREADY) begin
    rd_cnt_14 <= rd_cnt_14 + 1'b1;
  end
end

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    wr_cnt_14 <= 5'b0;
  end else if (AXI_14_BVALID && AXI_14_BREADY) begin
    wr_cnt_14 <= wr_cnt_14 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 14
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (14)
) u_axi_pmon_14 (
  .axi_arst_n              (axi_rst6_st0_n    ),
  .axi_aclk                (AXI_ACLK6_st0_buf ),
  .axi_awid                (AXI_14_AWID),
  .axi_awaddr              (AXI_14_AWADDR),
  .axi_awlen               (AXI_14_AWLEN),
  .axi_awsize              (AXI_14_AWSIZE),
  .axi_awburst             (AXI_14_AWBURST),
  .axi_awcache             (AXI_14_AWCACHE),
  .axi_awprot              (AXI_14_AWPROT),
  .axi_awvalid             (AXI_14_AWVALID),
  .axi_awready             (AXI_14_AWREADY),
  .axi_wdata               (AXI_14_WDATA),
  .axi_wstrb               (AXI_14_WSTRB),
  .axi_wlast               (AXI_14_WLAST),
  .axi_wvalid              (AXI_14_WVALID),
  .axi_wready              (AXI_14_WREADY),
  .axi_bready              (AXI_14_BREADY),
  .axi_bid                 (AXI_14_BID),
  .axi_bresp               (AXI_14_BRESP),
  .axi_bvalid              (AXI_14_BVALID),
  .axi_arid                (AXI_14_ARID),
  .axi_araddr              (AXI_14_ARADDR),
  .axi_arlen               (AXI_14_ARLEN),
  .axi_arsize              (AXI_14_ARSIZE),
  .axi_arburst             (AXI_14_ARBURST),
  .axi_arcache             (AXI_14_ARCACHE),
  .axi_arvalid             (AXI_14_ARVALID),
  .axi_arready             (AXI_14_ARREADY),
  .axi_rready              (AXI_14_RREADY),
  .axi_rid                 (AXI_14_RID),
  .axi_rdata               (AXI_14_RDATA),
  .axi_rresp               (AXI_14_RRESP),
  .axi_rlast               (AXI_14_RLAST),
  .axi_rvalid              (AXI_14_RVALID)
);
// synthesis translate on

////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_TG - 15
////////////////////////////////////////////////////////////////////////////////
// assign AXI_15_ARADDR = {vio_tg_glb_start_addr_15[32:28],o_m_axi_araddr_15[27:0]};
// assign AXI_15_AWADDR = {vio_tg_glb_start_addr_15[32:28],o_m_axi_awaddr_15[27:0]};

atg_axi#(
  .SIMULATION                          (SIMULATION),
  .MEM_TYPE                            ("DDR4"),
  .MEM_ARCH                            ("ULTRASCALE"),
  //.APP_DATA_WIDTH                      (APP_DATA_WIDTH),
  .APP_ADDR_WIDTH                      (APP_ADDR_WIDTH),
  .C_AXI_ID_WIDTH                      (6),
  .C_AXI_ADDR_WIDTH                    (APP_ADDR_WIDTH),
  //.C_AXI_DATA_WIDTH                    (APP_DATA_WIDTH),
  .TG_PATTERN_MODE_PRBS_ADDR_WIDTH     (28),
  .ECC                                 ("OFF"),
  //.NUM_DQ_PINS                         (32),
  `ifdef OPT_DATA_W
    .APP_DATA_WIDTH(64),
    .C_AXI_DATA_WIDTH(64),
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(16),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(8),
      `endif
    `else
      `ifdef NCKPCLK_2
        .NUM_DQ_PINS(64),
        .nCK_PER_CLK(2),
      `else
        .nCK_PER_CLK(4),
        .NUM_DQ_PINS(32),
      `endif
    .APP_DATA_WIDTH(APP_DATA_WIDTH),
    .C_AXI_DATA_WIDTH(APP_DATA_WIDTH),
  `endif
  .DEFAULT_MODE                        ("2018_1")
) u_atg_axi_15 (
  .i_TG_PATTERN_MODE_PRBS_ADDR_SEED    (28'b0),
  .i_clk                               (AXI_ACLK6_st0_buf),
  .i_rst                               (~axi_rst6_st0_n),
  .i_init_calib_complete               (apb_seq_complete_6_st0_r2),
  .compare_error                       (axi_15_data_msmatch_err),
  .vio_tg_rst                          (vio_tg_rst_15),
  .vio_tg_start                        (vio_tg_start_15),
  .vio_tg_err_chk_en                   (vio_tg_err_chk_en_15),
  .vio_tg_err_clear                    (vio_tg_err_clear_15),
  .vio_tg_instr_addr_mode              (vio_tg_instr_addr_mode_15),
  .vio_tg_instr_data_mode              (vio_tg_instr_data_mode_15),
  .vio_tg_instr_rw_mode                (vio_tg_instr_rw_mode_15),
  .vio_tg_instr_rw_submode             (vio_tg_instr_rw_submode_15),
  .vio_tg_instr_num_of_iter            (vio_tg_instr_num_of_iter_15),
  .vio_tg_instr_nxt_instr              (vio_tg_instr_nxt_instr_15),
  .vio_tg_restart                      (vio_tg_restart_15),
  .vio_tg_pause                        (vio_tg_pause_15),
  .vio_tg_err_clear_all                (vio_tg_err_clear_all_15),
  .vio_tg_err_continue                 (vio_tg_err_continue_15),
  .vio_tg_instr_program_en             (vio_tg_instr_program_en_15),
  .vio_tg_direct_instr_en              (vio_tg_direct_instr_en_15),
  .vio_tg_instr_num                    (vio_tg_instr_num_15),
  .vio_tg_instr_victim_mode            (vio_tg_instr_victim_mode_15),
  .vio_tg_instr_victim_aggr_delay      (vio_tg_instr_victim_aggr_delay_15),
  .vio_tg_instr_victim_select          (vio_tg_instr_victim_select_15),
  .vio_tg_instr_m_nops_btw_n_burst_m   (vio_tg_instr_m_nops_btw_n_burst_m_15),
  .vio_tg_instr_m_nops_btw_n_burst_n   (vio_tg_instr_m_nops_btw_n_burst_n_15),
  .vio_tg_seed_program_en              (vio_tg_seed_program_en_15),
  .vio_tg_seed_num                     (vio_tg_seed_num_15),
  .vio_tg_seed                         (vio_tg_seed_15),
  .vio_tg_glb_victim_bit               (vio_tg_glb_victim_bit_15),
  .vio_tg_glb_start_addr               (vio_tg_glb_start_addr_15),
  .vio_tg_glb_qdriv_rw_submode         (2'b00),
  .o_wrt_rqt_over_flow                 (),
  .vio_tg_status_state                 (vio_tg_status_state_15),
  .vio_tg_status_err_bit_valid         (vio_tg_status_err_bit_valid_15),
  .vio_tg_status_err_bit               (vio_tg_status_err_bit_15),
  .vio_tg_status_err_cnt               (vio_tg_status_err_cnt_15),
  .vio_tg_status_err_addr              (vio_tg_status_err_addr_15),
  .vio_tg_status_exp_bit_valid         (vio_tg_status_exp_bit_valid_15),
  .vio_tg_status_exp_bit               (vio_tg_status_exp_bit_15),
  .vio_tg_status_read_bit_valid        (vio_tg_status_read_bit_valid_15),
  .vio_tg_status_read_bit              (vio_tg_status_read_bit_15),
  .vio_tg_status_first_err_bit_valid   (vio_tg_status_first_err_bit_valid_15),
  .vio_tg_status_first_err_bit         (vio_tg_status_first_err_bit_15),
  .vio_tg_status_first_err_addr        (vio_tg_status_first_err_addr_15),
  .vio_tg_status_first_exp_bit_valid   (vio_tg_status_first_exp_bit_valid_15),
  .vio_tg_status_first_exp_bit         (vio_tg_status_first_exp_bit_15),
  .vio_tg_status_first_read_bit_valid  (vio_tg_status_first_read_bit_valid_15),
  .vio_tg_status_first_read_bit        (vio_tg_status_first_read_bit_15),
  .vio_tg_status_err_bit_sticky_valid  (vio_tg_status_err_bit_sticky_valid_15),
  .vio_tg_status_err_bit_sticky        (vio_tg_status_err_bit_sticky_15),
  .vio_tg_status_err_cnt_sticky        (vio_tg_status_err_cnt_sticky_15),
  .vio_tg_status_err_type_valid        (vio_tg_status_err_type_valid_15),
  .vio_tg_status_err_type              (vio_tg_status_err_type_15),
  .vio_tg_status_wr_done               (vio_tg_status_wr_done_15),
  .vio_tg_status_done                  (boot_mode_done_15),
  .vio_tg_status_watch_dog_hang        (vio_tg_status_watch_dog_hang_15),
  .tg_ila_debug                        (tg_ila_debug_15),
  .tg_qdriv_submode11_app_rd           (1'b0),
   // Slave Interface Write Address Ports
  .i_m_axi_awready                     ('0),
  .o_m_axi_awid                        (),
  .o_m_axi_awaddr                      (),
  .o_m_axi_awlen                       (),
  .o_m_axi_awsize                      (),
  .o_m_axi_awburst                     (),
  .o_m_axi_awlock                      (),
  .o_m_axi_awcache                     (),
  .o_m_axi_awprot                      (),
  .o_m_axi_awvalid                     (),
  // Slave Interface Write Data Ports
  .i_m_axi_wready                      ('0),
  .o_m_axi_wdata                       (),
  .o_m_axi_wstrb                       (),
  .o_m_axi_wlast                       (),
  .o_m_axi_wvalid                      (),
  // Slave Interface Write Response Ports
  .i_m_axi_bid                         ('0),
  .i_m_axi_bresp                       ('0),
  .i_m_axi_bvalid                      ('0),
  .o_m_axi_bready                      (),
  .i_m_axi_arready                     ('0),
  // Slave Interface Read Address Ports
  .o_m_axi_arid                        (),
  .o_m_axi_araddr                      (),
  .o_m_axi_arlen                       (),
  .o_m_axi_arsize                      (),
  .o_m_axi_arburst                     (),
  .o_m_axi_arlock                      (),
  .o_m_axi_arcache                     (),
  .o_m_axi_arprot                      (),
  .o_m_axi_arvalid                     (),
  // Slave Interface Read Data Ports
  .i_m_axi_rid                         ('0),
  .i_m_axi_rresp                       ('0),
  .i_m_axi_rvalid                      ('0),
  .i_m_axi_rdata                       ('0),
  .i_m_axi_rlast                       ('0),
  .o_m_axi_rready                      ()
);

  //  mosi signals
  assign AXI_15_AWID    = axi4_hbm_chs_li[15].awid;
  assign AXI_15_AWADDR  = axi4_hbm_chs_li[15].awaddr[0][32:0];
  assign AXI_15_AWLEN   = axi4_hbm_chs_li[15].awlen;
  assign AXI_15_AWSIZE  = axi4_hbm_chs_li[15].awsize;
  assign AXI_15_AWBURST = axi4_hbm_chs_li[15].awburst;
  // assign AXI_15_awlock = axi4_hbm_chs_li[15].awlock;
  assign AXI_15_AWCACHE = axi4_hbm_chs_li[15].awcache;
  assign AXI_15_AWPROT  = axi4_hbm_chs_li[15].awprot;
  assign AXI_15_AWVALID = axi4_hbm_chs_li[15].awvalid;
  assign AXI_15_WDATA   = axi4_hbm_chs_li[15].wdata;
  assign AXI_15_WSTRB   = axi4_hbm_chs_li[15].wstrb;
  assign AXI_15_WLAST   = axi4_hbm_chs_li[15].wlast;
  assign AXI_15_WVALID  = axi4_hbm_chs_li[15].wvalid;
  assign AXI_15_BREADY  = axi4_hbm_chs_li[15].bready;
  assign AXI_15_ARID    = axi4_hbm_chs_li[15].arid;
  assign AXI_15_ARADDR  = axi4_hbm_chs_li[15].araddr[0][32:0];
  assign AXI_15_ARLEN   = axi4_hbm_chs_li[15].arlen;
  assign AXI_15_ARSIZE  = axi4_hbm_chs_li[15].arsize;
  assign AXI_15_ARBURST = axi4_hbm_chs_li[15].arburst;
  // assign ( = axi4_hbm_chs_li[15].arburst;
  assign AXI_15_ARCACHE = axi4_hbm_chs_li[15].arcache;
  // assign ( = axi4_hbm_chs_li[15].arprot;
  assign AXI_15_ARVALID = axi4_hbm_chs_li[15].arvalid;
  assign AXI_15_RREADY  = axi4_hbm_chs_li[15].rready;

  //  miso signals
  assign axi4_hbm_chs_lo[15].awready = AXI_15_AWREADY;
  assign axi4_hbm_chs_lo[15].wready  = AXI_15_WREADY;
  assign axi4_hbm_chs_lo[15].bid     = AXI_15_BID;
  assign axi4_hbm_chs_lo[15].bresp   = AXI_15_BRESP;
  assign axi4_hbm_chs_lo[15].bvalid  = AXI_15_BVALID;
  assign axi4_hbm_chs_lo[15].arready = AXI_15_ARREADY;
  assign axi4_hbm_chs_lo[15].rid     = AXI_15_RID;
  assign axi4_hbm_chs_lo[15].rresp   = AXI_15_RRESP;
  assign axi4_hbm_chs_lo[15].rvalid  = AXI_15_RVALID;
  assign axi4_hbm_chs_lo[15].rdata   = AXI_15_RDATA;
  assign axi4_hbm_chs_lo[15].rlast   = AXI_15_RLAST;



assign  vio_tg_rst_15 =  1'd0;
assign  i_force_vio_tg_status_done_15 = 16'h0000;
assign  i_vio_enable_atg_axi_x_15 =  16'hffff;
assign  i_vio_status_out_sel_atg_axi_x_15 =  16'hffff;
assign  vio_tg_restart_15 =  'd0;
assign  vio_tg_pause_15 =  'd0;
assign  vio_tg_err_chk_en_15 =  'd0;
assign  vio_tg_err_clear_15 =  'd0;
assign  vio_tg_err_clear_all_15 =  'd0;
assign  vio_tg_err_continue_15 =  'd0;
assign  vio_tg_instr_program_en_15 =  'd0;
assign  vio_tg_direct_instr_en_15 =  'd0;
assign  vio_tg_instr_num_15 =  'd0;
assign  vio_tg_instr_addr_mode_15 =  'd0;
assign  vio_tg_instr_data_mode_15 =  'd0;
assign  vio_tg_instr_rw_mode_15 =  'd0;
assign  vio_tg_instr_rw_submode_15 =  'd0;
assign  vio_tg_instr_victim_mode_15 =  'd0;
assign  vio_tg_instr_victim_aggr_delay_15 =  'd0;
assign  vio_tg_instr_victim_select_15 =  'd0;
assign  vio_tg_instr_num_of_iter_15 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_m_15 =  'd0;
assign  vio_tg_instr_m_nops_btw_n_burst_n_15 =  'd0;
assign  vio_tg_instr_nxt_instr_15 =  'd0;
assign  vio_tg_seed_program_en_15 =  'd0;
assign  vio_tg_seed_num_15 =  'd0;
assign  vio_tg_seed_15 =  'd0;
assign  vio_tg_glb_start_addr_15 = 33'h0_FF00_0000;

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    rd_cnt_15 <= 5'b0;
  end else if (AXI_15_RVALID && AXI_15_RREADY) begin
    rd_cnt_15 <= rd_cnt_15 + 1'b1;
  end
end

always@(posedge AXI_ACLK6_st0_buf or negedge axi_rst6_st0_n) begin
  if (~axi_rst6_st0_n) begin
    wr_cnt_15 <= 5'b0;
  end else if (AXI_15_BVALID && AXI_15_BREADY) begin
    wr_cnt_15 <= wr_cnt_15 + 1'b1;
  end
end

// synthesis translate off
////////////////////////////////////////////////////////////////////////////////
// Instantiating AXI_PMON - 15
////////////////////////////////////////////////////////////////////////////////
axi_pmon_v1_0 #(
    .C_AXI_ID_WIDTH        (6),
    .C_AXI_ADDR_WIDTH      (33),
    .C_AXI_DATA_WIDTH      (256),
    .SIMULATION            ("TRUE"),
    .tCK                   (2222),
    .PARAM_AXI_TG_ID       (15)
) u_axi_pmon_15 (
  .axi_arst_n              (axi_rst6_st0_n    ),
  .axi_aclk                (AXI_ACLK6_st0_buf ),
  .axi_awid                (AXI_15_AWID),
  .axi_awaddr              (AXI_15_AWADDR),
  .axi_awlen               (AXI_15_AWLEN),
  .axi_awsize              (AXI_15_AWSIZE),
  .axi_awburst             (AXI_15_AWBURST),
  .axi_awcache             (AXI_15_AWCACHE),
  .axi_awprot              (AXI_15_AWPROT),
  .axi_awvalid             (AXI_15_AWVALID),
  .axi_awready             (AXI_15_AWREADY),
  .axi_wdata               (AXI_15_WDATA),
  .axi_wstrb               (AXI_15_WSTRB),
  .axi_wlast               (AXI_15_WLAST),
  .axi_wvalid              (AXI_15_WVALID),
  .axi_wready              (AXI_15_WREADY),
  .axi_bready              (AXI_15_BREADY),
  .axi_bid                 (AXI_15_BID),
  .axi_bresp               (AXI_15_BRESP),
  .axi_bvalid              (AXI_15_BVALID),
  .axi_arid                (AXI_15_ARID),
  .axi_araddr              (AXI_15_ARADDR),
  .axi_arlen               (AXI_15_ARLEN),
  .axi_arsize              (AXI_15_ARSIZE),
  .axi_arburst             (AXI_15_ARBURST),
  .axi_arcache             (AXI_15_ARCACHE),
  .axi_arvalid             (AXI_15_ARVALID),
  .axi_arready             (AXI_15_ARREADY),
  .axi_rready              (AXI_15_RREADY),
  .axi_rid                 (AXI_15_RID),
  .axi_rdata               (AXI_15_RDATA),
  .axi_rresp               (AXI_15_RRESP),
  .axi_rlast               (AXI_15_RLAST),
  .axi_rvalid              (AXI_15_RVALID)
);
// synthesis translate on

`ifdef SIMULATION_MODE
assign vio_tg_start_0 = 1'b1;
assign vio_tg_start_1 = 1'b1;
assign vio_tg_start_2 = 1'b1;
assign vio_tg_start_3 = 1'b1;
assign vio_tg_start_4 = 1'b1;
assign vio_tg_start_5 = 1'b1;
assign vio_tg_start_6 = 1'b1;
assign vio_tg_start_7 = 1'b1;
assign vio_tg_start_8 = 1'b1;
assign vio_tg_start_9 = 1'b1;
assign vio_tg_start_10 = 1'b1;
assign vio_tg_start_11 = 1'b1;
assign vio_tg_start_12 = 1'b1;
assign vio_tg_start_13 = 1'b1;
assign vio_tg_start_14 = 1'b1;
assign vio_tg_start_15 = 1'b1;
`else
assign vio_tg_start_0 = 1'b1;
assign vio_tg_start_1 = 1'b1;
assign vio_tg_start_2 = 1'b1;
assign vio_tg_start_3 = 1'b1;
assign vio_tg_start_4 = 1'b1;
assign vio_tg_start_5 = 1'b1;
assign vio_tg_start_6 = 1'b1;
assign vio_tg_start_7 = 1'b1;
assign vio_tg_start_8 = 1'b1;
assign vio_tg_start_9 = 1'b1;
assign vio_tg_start_10 = 1'b1;
assign vio_tg_start_11 = 1'b1;
assign vio_tg_start_12 = 1'b1;
assign vio_tg_start_13 = 1'b1;
assign vio_tg_start_14 = 1'b1;
assign vio_tg_start_15 = 1'b1;
`endif




assign ext_apb_seq_complete_0_s = 1'b0;



////////////////////////////////////////////////////////////////////////////////
// Generating AXI transaciton error status signal
////////////////////////////////////////////////////////////////////////////////
assign axi_trans_err = axi_00_data_msmatch_err || axi_01_data_msmatch_err ||
                       axi_02_data_msmatch_err || axi_03_data_msmatch_err ||
                       axi_04_data_msmatch_err || axi_05_data_msmatch_err ||
                       axi_06_data_msmatch_err || axi_07_data_msmatch_err ||
                       axi_08_data_msmatch_err || axi_09_data_msmatch_err ||
                       axi_10_data_msmatch_err || axi_11_data_msmatch_err ||
                       axi_12_data_msmatch_err || axi_13_data_msmatch_err ||
                       axi_14_data_msmatch_err || axi_15_data_msmatch_err ||
                       axi_16_data_msmatch_err || axi_17_data_msmatch_err ||
                       axi_18_data_msmatch_err || axi_19_data_msmatch_err ||
                       axi_20_data_msmatch_err || axi_21_data_msmatch_err ||
                       axi_22_data_msmatch_err || axi_23_data_msmatch_err ||
                       axi_24_data_msmatch_err || axi_25_data_msmatch_err ||
                       axi_26_data_msmatch_err || axi_27_data_msmatch_err ||
                       axi_28_data_msmatch_err || axi_29_data_msmatch_err ||
                       axi_30_data_msmatch_err || axi_31_data_msmatch_err ;



  end // lv3_hbm

  else begin : noop
  end : noop

endmodule
