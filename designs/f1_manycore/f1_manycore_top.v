/*
* f1_manycore_top.v
*
* top level of the F1_manycore design on local FPGA
*/

`include "bsg_axi_bus_pkg.vh"

module f1_manycore_top
  import bsg_bladerunner_pkg::*;
#(
  parameter pcie_width_p = 4
  ,parameter pcie_speed_p = 1
  ,parameter pcie_axi_id_width_p = 4
  ,parameter pcie_axi_data_width_p = 64
  ,parameter pcie_axi_addr_width_p = 64
) (
  input sys_clk_i_p
  ,input sys_clk_i_n
  ,input sys_resetn_i
  ,input cpu_reset_i
  ,input [pcie_width_p-1:0] pcie_i_p
  ,input [pcie_width_p-1:0] pcie_i_n
  ,output [pcie_width_p-1:0] pcie_o_p
  ,output [pcie_width_p-1:0] pcie_o_n
  ,output led_o
);

  localparam mem_axi_id_width_lp = axi_id_width_p;
  localparam mem_axi_addr_width_lp = axi_addr_width_p;
  localparam mem_axi_data_width_lp = axi_data_width_p;

  wire sys_rst_n_buf_lo;
  wire user_clk_lo;
  wire user_resetn_lo;
  wire user_link_up_lo;

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

  xilinx_dma_pcie_ep #(
    .PL_LINK_CAP_MAX_LINK_WIDTH(pcie_width_p    ),
    .PL_LINK_CAP_MAX_LINK_SPEED(pcie_speed_p    ),
    .C_DATA_WIDTH              (pcie_axi_data_width_p),
    .C_M_AXI_ID_WIDTH          (pcie_axi_id_width_p  ),
    .C_M_AXI_ADDR_WIDTH        (pcie_axi_addr_width_p)
  ) xdma_inst (
    .pci_exp_txp    (pcie_o_p    ),
    .pci_exp_txn    (pcie_o_n    ),
    .pci_exp_rxp    (pcie_i_p    ),
    .pci_exp_rxn    (pcie_i_n    ),
    .sys_clk_p_i    (sys_clk_i_p    ),
    .sys_clk_n_i    (sys_clk_i_n    ),
    .sys_rst_n_i    (sys_resetn_i    ),
    .sys_rst_n_buf_o(sys_rst_n_buf_lo),
    .user_clk_o     (user_clk_lo     ),
    .user_resetn_o  (user_resetn_lo  ),
    .user_link_up_o (user_link_up_lo ),
    .leds_o         (),
    // AXIL
    .m_axil_awaddr  (m_axil_awaddr  ),
    .m_axil_awvalid (m_axil_awvalid ),
    .m_axil_awready (m_axil_awready ),
    .m_axil_wdata   (m_axil_wdata   ),
    .m_axil_wstrb   (m_axil_wstrb   ),
    .m_axil_wvalid  (m_axil_wvalid  ),
    .m_axil_wready  (m_axil_wready  ),
    .m_axil_bresp   (m_axil_bresp   ),
    .m_axil_bvalid  (m_axil_bvalid  ),
    .m_axil_bready  (m_axil_bready  ),
    .m_axil_araddr  (m_axil_araddr  ),
    .m_axil_arvalid (m_axil_arvalid ),
    .m_axil_arready (m_axil_arready ),
    .m_axil_rdata   (m_axil_rdata   ),
    .m_axil_rresp   (m_axil_rresp   ),
    .m_axil_rvalid  (m_axil_rvalid  ),
    .m_axil_rready  (m_axil_rready  ),
    // AXI4
    .m_axi_awid     (m_axi_awid     ),
    .m_axi_awaddr   (m_axi_awaddr   ),
    .m_axi_awlen    (m_axi_awlen    ),
    .m_axi_awsize   (m_axi_awsize   ),
    .m_axi_awburst  (m_axi_awburst  ),
    .m_axi_awvalid  (m_axi_awvalid  ),
    .m_axi_awready  (m_axi_awready  ),
    .m_axi_wdata    (m_axi_wdata    ),
    .m_axi_wstrb    (m_axi_wstrb    ),
    .m_axi_wlast    (m_axi_wlast    ),
    .m_axi_wvalid   (m_axi_wvalid   ),
    .m_axi_wready   (m_axi_wready   ),
    .m_axi_bid      (m_axi_bid      ),
    .m_axi_bresp    (m_axi_bresp    ),
    .m_axi_bvalid   (m_axi_bvalid   ),
    .m_axi_bready   (m_axi_bready   ),
    .m_axi_arid     (m_axi_arid     ),
    .m_axi_araddr   (m_axi_araddr   ),
    .m_axi_arlen    (m_axi_arlen    ),
    .m_axi_arsize   (m_axi_arsize   ),
    .m_axi_arburst  (m_axi_arburst  ),
    .m_axi_arvalid  (m_axi_arvalid  ),
    .m_axi_arready  (m_axi_arready  ),
    .m_axi_rid      (m_axi_rid      ),
    .m_axi_rdata    (m_axi_rdata    ),
    .m_axi_rresp    (m_axi_rresp    ),
    .m_axi_rlast    (m_axi_rlast    ),
    .m_axi_rvalid   (m_axi_rvalid   ),
    .m_axi_rready   (m_axi_rready   ),
    // AXI4 Bypass
    .m_axib_awid    (m_axib_awid    ),
    .m_axib_awaddr  (m_axib_awaddr  ),
    .m_axib_awlen   (m_axib_awlen   ),
    .m_axib_awsize  (m_axib_awsize  ),
    .m_axib_awburst (m_axib_awburst ),
    .m_axib_awvalid (m_axib_awvalid ),
    .m_axib_awready (m_axib_awready ),
    .m_axib_wdata   (m_axib_wdata   ),
    .m_axib_wstrb   (m_axib_wstrb   ),
    .m_axib_wlast   (m_axib_wlast   ),
    .m_axib_wvalid  (m_axib_wvalid  ),
    .m_axib_wready  (m_axib_wready  ),
    .m_axib_bid     (m_axib_bid     ),
    .m_axib_bresp   (m_axib_bresp   ),
    .m_axib_bvalid  (m_axib_bvalid  ),
    .m_axib_bready  (m_axib_bready  ),
    .m_axib_arid    (m_axib_arid    ),
    .m_axib_araddr  (m_axib_araddr  ),
    .m_axib_arlen   (m_axib_arlen   ),
    .m_axib_arsize  (m_axib_arsize  ),
    .m_axib_arburst (m_axib_arburst ),
    .m_axib_arvalid (m_axib_arvalid ),
    .m_axib_arready (m_axib_arready ),
    .m_axib_rid     (m_axib_rid     ),
    .m_axib_rdata   (m_axib_rdata   ),
    .m_axib_rresp   (m_axib_rresp   ),
    .m_axib_rlast   (m_axib_rlast   ),
    .m_axib_rvalid  (m_axib_rvalid  ),
    .m_axib_rready  (m_axib_rready  )
  );


  // ---------------------------------------------
  // from 100MHz to 125MHz domain
  // ---------------------------------------------
  wire clk_i    = user_clk_lo   ;
  wire resetn_i = user_resetn_lo;

  // ---------------------------------------------
  // reset debounce
  // ---------------------------------------------

  localparam counter_width_p = 22;

  logic rst_dbnced_lo;
  qcl_debounce #(.width_p(counter_width_p)) dbnc (
    .clk_i(clk_i        ),
    .i    (cpu_reset_i  ),
    .o    (rst_dbnced_lo)
  );

  // TODO: add system hard reset
  wire mc_resetn_i = ~ (rst_dbnced_lo  | ~resetn_i);

  assign led_o = rst_dbnced_lo;


  // ---------------------------------------------
  // axil ocl interface
  // ---------------------------------------------
  `declare_bsg_axil_bus_s(1, sh_ocl_si_s, sh_ocl_so_s);
  sh_ocl_si_s s_axil_ocl_li_cast;
  sh_ocl_so_s s_axil_ocl_lo_cast;

  assign s_axil_ocl_li_cast.awaddr  = m_axil_awaddr;
  assign s_axil_ocl_li_cast.awvalid = m_axil_awvalid;
  assign s_axil_ocl_li_cast.wdata   = m_axil_wdata;
  assign s_axil_ocl_li_cast.wstrb   = m_axil_wstrb;
  assign s_axil_ocl_li_cast.wvalid  = m_axil_wvalid;
  assign s_axil_ocl_li_cast.bready  = m_axil_bready;
  assign s_axil_ocl_li_cast.araddr  = m_axil_araddr;
  assign s_axil_ocl_li_cast.arvalid = m_axil_arvalid;
  assign s_axil_ocl_li_cast.rready  = m_axil_rready;

  assign m_axil_awready = s_axil_ocl_lo_cast.awready;
  assign m_axil_wready  = s_axil_ocl_lo_cast.wready;
  assign m_axil_bresp   = s_axil_ocl_lo_cast.bresp;
  assign m_axil_bvalid  = s_axil_ocl_lo_cast.bvalid;
  assign m_axil_arready = s_axil_ocl_lo_cast.arready;
  assign m_axil_rdata   = s_axil_ocl_lo_cast.rdata;
  assign m_axil_rresp   = s_axil_ocl_lo_cast.rresp;
  assign m_axil_rvalid  = s_axil_ocl_lo_cast.rvalid;


  // ---------------------------------------------
  // axi4 pcis interface
  // ---------------------------------------------
  `declare_bsg_axi4_bus_s(1, pcie_axi_id_width_p, pcie_axi_addr_width_p, pcie_axi_data_width_p, pcie_axi_mo_s, pcie_axi_mi_s);
  pcie_axi_mo_s m_pcie_axi_lo_cast;
  pcie_axi_mi_s m_pcie_axi_li_cast;

  `declare_bsg_axi4_bus_s(1, mem_axi_id_width_lp, mem_axi_addr_width_lp, mem_axi_data_width_lp, mem_axi_mosi_s, mem_axi_miso_s);
  mem_axi_mosi_s s_pcis_axi_li_cast, m_ddr_axi_lo_cast;
  mem_axi_miso_s s_pcis_axi_lo_cast, m_ddr_axi_li_cast;

  // -----------------------------------------
  // from PCIe AXI4 bypass port
  // -----------------------------------------
  assign m_pcie_axi_lo_cast.awid     = m_axib_awid;
  assign m_pcie_axi_lo_cast.awaddr   = m_axib_awaddr;
  assign m_pcie_axi_lo_cast.awlen    = m_axib_awlen;
  assign m_pcie_axi_lo_cast.awsize   = m_axib_awsize;
  assign m_pcie_axi_lo_cast.awburst  = m_axib_awburst;
  assign m_pcie_axi_lo_cast.awprot   = '0; // m_axib_awprot
  assign m_pcie_axi_lo_cast.awregion = '0;
  assign m_pcie_axi_lo_cast.awqos    = '0;
  assign m_pcie_axi_lo_cast.awvalid  = m_axib_awvalid;
  assign m_pcie_axi_lo_cast.awlock   = '0;  // m_axib_awlock
  assign m_pcie_axi_lo_cast.awcache  = '0;  // m_axib_awcache
  assign m_pcie_axi_lo_cast.wdata    = m_axib_wdata;
  assign m_pcie_axi_lo_cast.wstrb    = m_axib_wstrb;
  assign m_pcie_axi_lo_cast.wlast    = m_axib_wlast;
  assign m_pcie_axi_lo_cast.wvalid   = m_axib_wvalid;
  assign m_pcie_axi_lo_cast.bready   = m_axib_bready;
  assign m_pcie_axi_lo_cast.arid     = m_axib_arid;
  assign m_pcie_axi_lo_cast.araddr   = m_axib_araddr;
  assign m_pcie_axi_lo_cast.arlen    = m_axib_arlen;
  assign m_pcie_axi_lo_cast.arsize   = m_axib_arsize;
  assign m_pcie_axi_lo_cast.arburst  = m_axib_arburst;
  assign m_pcie_axi_lo_cast.arprot   = '0;  // m_axib_arprot
  assign m_pcie_axi_lo_cast.arregion = '0;
  assign m_pcie_axi_lo_cast.arqos    = '0;
  assign m_pcie_axi_lo_cast.arvalid  = m_axib_arvalid;
  assign m_pcie_axi_lo_cast.arlock   = '0;  // m_axib_arlock
  assign m_pcie_axi_lo_cast.arcache  = '0;  // m_axib_arcache
  assign m_pcie_axi_lo_cast.rready   = m_axib_rready;

  assign m_axib_awready = m_pcie_axi_li_cast.awready;
  assign m_axib_wready  = m_pcie_axi_li_cast.wready;
  assign m_axib_bid     = m_pcie_axi_li_cast.bid;
  assign m_axib_bresp   = m_pcie_axi_li_cast.bresp;
  assign m_axib_bvalid  = m_pcie_axi_li_cast.bvalid;
  assign m_axib_arready = m_pcie_axi_li_cast.arready;
  assign m_axib_rid     = m_pcie_axi_li_cast.rid;
  assign m_axib_rdata   = m_pcie_axi_li_cast.rdata;
  assign m_axib_rresp   = m_pcie_axi_li_cast.rresp;
  assign m_axib_rlast   = m_pcie_axi_li_cast.rlast;
  assign m_axib_rvalid  = m_pcie_axi_li_cast.rvalid;

  axi_dwidth_converter_0 axi_dwidth_converter_64_256 (
    .s_axi_aclk    (clk_i                      ), // input wire s_axi_aclk
    .s_axi_aresetn (resetn_i                   ), // input wire s_axi_aresetn
    .s_axi_awid    (m_pcie_axi_lo_cast.awid     ), // input wire [3 : 0] s_axi_awid
    .s_axi_awaddr  (m_pcie_axi_lo_cast.awaddr   ), // input wire [63 : 0] s_axi_awaddr
    .s_axi_awlen   (m_pcie_axi_lo_cast.awlen    ), // input wire [7 : 0] s_axi_awlen
    .s_axi_awsize  (m_pcie_axi_lo_cast.awsize   ), // input wire [2 : 0] s_axi_awsize
    .s_axi_awburst (m_pcie_axi_lo_cast.awburst  ), // input wire [1 : 0] s_axi_awburst
    .s_axi_awlock  (m_pcie_axi_lo_cast.awlock   ), // input wire [0 : 0] s_axi_awlock
    .s_axi_awcache (m_pcie_axi_lo_cast.awcache  ), // input wire [3 : 0] s_axi_awcache
    .s_axi_awprot  (m_pcie_axi_lo_cast.awprot   ), // input wire [2 : 0] s_axi_awprot
    .s_axi_awregion(m_pcie_axi_lo_cast.awregion ), // input wire [3 : 0] s_axi_awregion
    .s_axi_awqos   (m_pcie_axi_lo_cast.awqos    ), // input wire [3 : 0] s_axi_awqos
    .s_axi_awvalid (m_pcie_axi_lo_cast.awvalid  ), // input wire s_axi_awvalid
    .s_axi_awready (m_pcie_axi_li_cast.awready  ), // output wire s_axi_awready
    .s_axi_wdata   (m_pcie_axi_lo_cast.wdata    ), // input wire [63 : 0] s_axi_wdata
    .s_axi_wstrb   (m_pcie_axi_lo_cast.wstrb    ), // input wire [7 : 0] s_axi_wstrb
    .s_axi_wlast   (m_pcie_axi_lo_cast.wlast    ), // input wire s_axi_wlast
    .s_axi_wvalid  (m_pcie_axi_lo_cast.wvalid   ), // input wire s_axi_wvalid
    .s_axi_wready  (m_pcie_axi_li_cast.wready   ), // output wire s_axi_wready
    .s_axi_bid     (m_pcie_axi_li_cast.bid      ), // output wire [3 : 0] s_axi_bid
    .s_axi_bresp   (m_pcie_axi_li_cast.bresp    ), // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid  (m_pcie_axi_li_cast.bvalid   ), // output wire s_axi_bvalid
    .s_axi_bready  (m_pcie_axi_lo_cast.bready   ), // input wire s_axi_bready
    .s_axi_arid    (m_pcie_axi_lo_cast.arid     ), // input wire [3 : 0] s_axi_arid
    .s_axi_araddr  (m_pcie_axi_lo_cast.araddr   ), // input wire [63 : 0] s_axi_araddr
    .s_axi_arlen   (m_pcie_axi_lo_cast.arlen    ), // input wire [7 : 0] s_axi_arlen
    .s_axi_arsize  (m_pcie_axi_lo_cast.arsize   ), // input wire [2 : 0] s_axi_arsize
    .s_axi_arburst (m_pcie_axi_lo_cast.arburst  ), // input wire [1 : 0] s_axi_arburst
    .s_axi_arlock  (m_pcie_axi_lo_cast.arlock   ), // input wire [0 : 0] s_axi_arlock
    .s_axi_arcache (m_pcie_axi_lo_cast.arcache  ), // input wire [3 : 0] s_axi_arcache
    .s_axi_arprot  (m_pcie_axi_lo_cast.arprot   ), // input wire [2 : 0] s_axi_arprot
    .s_axi_arregion(m_pcie_axi_lo_cast.arregion ), // input wire [3 : 0] s_axi_arregion
    .s_axi_arqos   (m_pcie_axi_lo_cast.arqos    ), // input wire [3 : 0] s_axi_arqos
    .s_axi_arvalid (m_pcie_axi_lo_cast.arvalid  ), // input wire s_axi_arvalid
    .s_axi_arready (m_pcie_axi_li_cast.arready  ), // output wire s_axi_arready
    .s_axi_rid     (m_pcie_axi_li_cast.rid      ), // output wire [3 : 0] s_axi_rid
    .s_axi_rdata   (m_pcie_axi_li_cast.rdata    ), // output wire [63 : 0] s_axi_rdata
    .s_axi_rresp   (m_pcie_axi_li_cast.rresp    ), // output wire [1 : 0] s_axi_rresp
    .s_axi_rlast   (m_pcie_axi_li_cast.rlast    ), // output wire s_axi_rlast
    .s_axi_rvalid  (m_pcie_axi_li_cast.rvalid   ), // output wire s_axi_rvalid
    .s_axi_rready  (m_pcie_axi_lo_cast.rready   ), // input wire s_axi_rready

    .m_axi_awaddr  (s_pcis_axi_li_cast.awaddr  ), // output wire [63 : 0] m_axi_awaddr
    .m_axi_awlen   (s_pcis_axi_li_cast.awlen   ), // output wire [7 : 0] m_axi_awlen
    .m_axi_awsize  (s_pcis_axi_li_cast.awsize  ), // output wire [2 : 0] m_axi_awsize
    .m_axi_awburst (s_pcis_axi_li_cast.awburst ), // output wire [1 : 0] m_axi_awburst
    .m_axi_awlock  (s_pcis_axi_li_cast.awlock  ), // output wire [0 : 0] m_axi_awlock
    .m_axi_awcache (s_pcis_axi_li_cast.awcache ), // output wire [3 : 0] m_axi_awcache
    .m_axi_awprot  (s_pcis_axi_li_cast.awprot  ), // output wire [2 : 0] m_axi_awprot
    .m_axi_awregion(s_pcis_axi_li_cast.awregion), // output wire [3 : 0] m_axi_awregion
    .m_axi_awqos   (s_pcis_axi_li_cast.awqos   ), // output wire [3 : 0] m_axi_awqos
    .m_axi_awvalid (s_pcis_axi_li_cast.awvalid ), // output wire m_axi_awvalid
    .m_axi_awready (s_pcis_axi_lo_cast.awready ), // input wire m_axi_awready
    .m_axi_wdata   (s_pcis_axi_li_cast.wdata   ), // output wire [255 : 0] m_axi_wdata
    .m_axi_wstrb   (s_pcis_axi_li_cast.wstrb   ), // output wire [31 : 0] m_axi_wstrb
    .m_axi_wlast   (s_pcis_axi_li_cast.wlast   ), // output wire m_axi_wlast
    .m_axi_wvalid  (s_pcis_axi_li_cast.wvalid  ), // output wire m_axi_wvalid
    .m_axi_wready  (s_pcis_axi_lo_cast.wready  ), // input wire m_axi_wready
    .m_axi_bresp   (s_pcis_axi_lo_cast.bresp   ), // input wire [1 : 0] m_axi_bresp
    .m_axi_bvalid  (s_pcis_axi_lo_cast.bvalid  ), // input wire m_axi_bvalid
    .m_axi_bready  (s_pcis_axi_li_cast.bready  ), // output wire m_axi_bready
    .m_axi_araddr  (s_pcis_axi_li_cast.araddr  ), // output wire [63 : 0] m_axi_araddr
    .m_axi_arlen   (s_pcis_axi_li_cast.arlen   ), // output wire [7 : 0] m_axi_arlen
    .m_axi_arsize  (s_pcis_axi_li_cast.arsize  ), // output wire [2 : 0] m_axi_arsize
    .m_axi_arburst (s_pcis_axi_li_cast.arburst ), // output wire [1 : 0] m_axi_arburst
    .m_axi_arlock  (s_pcis_axi_li_cast.arlock  ), // output wire [0 : 0] m_axi_arlock
    .m_axi_arcache (s_pcis_axi_li_cast.arcache ), // output wire [3 : 0] m_axi_arcache
    .m_axi_arprot  (s_pcis_axi_li_cast.arprot  ), // output wire [2 : 0] m_axi_arprot
    .m_axi_arregion(s_pcis_axi_li_cast.arregion), // output wire [3 : 0] m_axi_arregion
    .m_axi_arqos   (s_pcis_axi_li_cast.arqos   ), // output wire [3 : 0] m_axi_arqos
    .m_axi_arvalid (s_pcis_axi_li_cast.arvalid ), // output wire m_axi_arvalid
    .m_axi_arready (s_pcis_axi_lo_cast.arready ), // input wire m_axi_arready
    .m_axi_rdata   (s_pcis_axi_lo_cast.rdata   ), // input wire [255 : 0] m_axi_rdata
    .m_axi_rresp   (s_pcis_axi_lo_cast.rresp   ), // input wire [1 : 0] m_axi_rresp
    .m_axi_rlast   (s_pcis_axi_lo_cast.rlast   ), // input wire m_axi_rlast
    .m_axi_rvalid  (s_pcis_axi_lo_cast.rvalid  ), // input wire m_axi_rvalid
    .m_axi_rready  (s_pcis_axi_li_cast.rready  )  // output wire m_axi_rready
  );

  assign s_pcis_axi_li_cast.awid    = '0;
  assign s_pcis_axi_li_cast.arid    = '0;

  bsg_bladerunner_wrapper #(
    .axi_id_width_p  (mem_axi_id_width_lp)
    ,.axi_addr_width_p(mem_axi_addr_width_lp)
    ,.axi_data_width_p(mem_axi_data_width_lp)
  ) bladerunner_inst (
    .clk_i           (clk_i           ),
    .reset_i         (cpu_reset_i     ),
    // AXI-Lite
    .s_axil_awaddr_i (s_axil_ocl_li_cast.awaddr ),
    .s_axil_awvalid_i(s_axil_ocl_li_cast.awvalid),
    .s_axil_awready_o(s_axil_ocl_lo_cast.awready),
    .s_axil_wdata_i  (s_axil_ocl_li_cast.wdata  ),
    .s_axil_wstrb_i  (s_axil_ocl_li_cast.wstrb  ),
    .s_axil_wvalid_i (s_axil_ocl_li_cast.wvalid ),
    .s_axil_wready_o (s_axil_ocl_lo_cast.wready ),
    .s_axil_bresp_o  (s_axil_ocl_lo_cast.bresp  ),
    .s_axil_bvalid_o (s_axil_ocl_lo_cast.bvalid ),
    .s_axil_bready_i (s_axil_ocl_li_cast.bready ),
    .s_axil_araddr_i (s_axil_ocl_li_cast.araddr ),
    .s_axil_arvalid_i(s_axil_ocl_li_cast.arvalid),
    .s_axil_arready_o(s_axil_ocl_lo_cast.arready),
    .s_axil_rdata_o  (s_axil_ocl_lo_cast.rdata  ),
    .s_axil_rresp_o  (s_axil_ocl_lo_cast.rresp  ),
    .s_axil_rvalid_o (s_axil_ocl_lo_cast.rvalid ),
    .s_axil_rready_i (s_axil_ocl_li_cast.rready ),
    // AXI4 PCIS
    .s_axi_awid_i    (s_pcis_axi_li_cast.awid    ),
    .s_axi_awaddr_i  (s_pcis_axi_li_cast.awaddr  ),
    .s_axi_awlen_i   (s_pcis_axi_li_cast.awlen   ),
    .s_axi_awsize_i  (s_pcis_axi_li_cast.awsize  ),
    .s_axi_awburst_i (s_pcis_axi_li_cast.awburst ),
    .s_axi_awvalid_i (s_pcis_axi_li_cast.awvalid ),
    .s_axi_awready_o (s_pcis_axi_lo_cast.awready ),
    .s_axi_wdata_i   (s_pcis_axi_li_cast.wdata   ),
    .s_axi_wstrb_i   (s_pcis_axi_li_cast.wstrb   ),
    .s_axi_wlast_i   (s_pcis_axi_li_cast.wlast   ),
    .s_axi_wvalid_i  (s_pcis_axi_li_cast.wvalid  ),
    .s_axi_wready_o  (s_pcis_axi_lo_cast.wready  ),
    .s_axi_bid_o     (s_pcis_axi_lo_cast.bid     ),
    .s_axi_bresp_o   (s_pcis_axi_lo_cast.bresp   ),
    .s_axi_bvalid_o  (s_pcis_axi_lo_cast.bvalid  ),
    .s_axi_bready_i  (s_pcis_axi_li_cast.bready  ),
    .s_axi_arid_i    (s_pcis_axi_li_cast.arid    ),
    .s_axi_araddr_i  (s_pcis_axi_li_cast.araddr  ),
    .s_axi_arlen_i   (s_pcis_axi_li_cast.arlen   ),
    .s_axi_arsize_i  (s_pcis_axi_li_cast.arsize  ),
    .s_axi_arburst_i (s_pcis_axi_li_cast.arburst ),
    .s_axi_arvalid_i (s_pcis_axi_li_cast.arvalid ),
    .s_axi_arready_o (s_pcis_axi_lo_cast.arready ),
    .s_axi_rid_o     (s_pcis_axi_lo_cast.rid     ),
    .s_axi_rdata_o   (s_pcis_axi_lo_cast.rdata   ),
    .s_axi_rresp_o   (s_pcis_axi_lo_cast.rresp   ),
    .s_axi_rlast_o   (s_pcis_axi_lo_cast.rlast   ),
    .s_axi_rvalid_o  (s_pcis_axi_lo_cast.rvalid  ),
    .s_axi_rready_i  (s_pcis_axi_li_cast.rready  ),
    // AXI4 Master
    .m_axi_awid_o    (m_ddr_axi_lo_cast.awid    ),
    .m_axi_awaddr_o  (m_ddr_axi_lo_cast.awaddr  ),
    .m_axi_awlen_o   (m_ddr_axi_lo_cast.awlen   ),
    .m_axi_awsize_o  (m_ddr_axi_lo_cast.awsize  ),
    .m_axi_awburst_o (m_ddr_axi_lo_cast.awburst ),
    .m_axi_awvalid_o (m_ddr_axi_lo_cast.awvalid ),
    .m_axi_awready_i (m_ddr_axi_li_cast.awready ),
    .m_axi_wdata_o   (m_ddr_axi_lo_cast.wdata   ),
    .m_axi_wstrb_o   (m_ddr_axi_lo_cast.wstrb   ),
    .m_axi_wlast_o   (m_ddr_axi_lo_cast.wlast   ),
    .m_axi_wvalid_o  (m_ddr_axi_lo_cast.wvalid  ),
    .m_axi_wready_i  (m_ddr_axi_li_cast.wready ),
    .m_axi_bid_i     (m_ddr_axi_li_cast.bid    ),
    .m_axi_bresp_i   (m_ddr_axi_li_cast.bresp  ),
    .m_axi_bvalid_i  (m_ddr_axi_li_cast.bvalid ),
    .m_axi_bready_o  (m_ddr_axi_lo_cast.bready  ),
    .m_axi_arid_o    (m_ddr_axi_lo_cast.arid    ),
    .m_axi_araddr_o  (m_ddr_axi_lo_cast.araddr  ),
    .m_axi_arlen_o   (m_ddr_axi_lo_cast.arlen   ),
    .m_axi_arsize_o  (m_ddr_axi_lo_cast.arsize  ),
    .m_axi_arburst_o (m_ddr_axi_lo_cast.arburst ),
    .m_axi_arvalid_o (m_ddr_axi_lo_cast.arvalid ),
    .m_axi_arready_i (m_ddr_axi_li_cast.arready),
    .m_axi_rid_i     (m_ddr_axi_li_cast.rid    ),
    .m_axi_rdata_i   (m_ddr_axi_li_cast.rdata  ),
    .m_axi_rresp_i   (m_ddr_axi_li_cast.rresp  ),
    .m_axi_rlast_i   (m_ddr_axi_li_cast.rlast  ),
    .m_axi_rvalid_i  (m_ddr_axi_li_cast.rvalid ),
    .m_axi_rready_o  (m_ddr_axi_lo_cast.rready  )
  );


  // ---------------------------------------------
  // axi4 data interface
  // ---------------------------------------------
  axi_bram_ctrl_0 hb_mc_bram (
    .s_axi_aclk   (clk_i              ), // input wire s_axi_aclk
    .s_axi_aresetn(resetn_i           ), // input wire s_axi_aresetn
    .s_axi_awid   (m_ddr_axi_lo_cast.awid   ), // input wire [5 : 0] s_axi_awid
    .s_axi_awaddr (m_ddr_axi_lo_cast.awaddr[bram_addr_width_p-1:0] ), // input wire [17 : 0] s_axi_awaddr
    .s_axi_awlen  (m_ddr_axi_lo_cast.awlen  ), // input wire [7 : 0] s_axi_awlen
    .s_axi_awsize (m_ddr_axi_lo_cast.awsize ), // input wire [2 : 0] s_axi_awsize
    .s_axi_awburst(m_ddr_axi_lo_cast.awburst), // input wire [1 : 0] s_axi_awburst
    .s_axi_awlock (m_ddr_axi_lo_cast.awlock ), // input wire s_axi_awlock
    .s_axi_awcache(m_ddr_axi_lo_cast.awcache), // input wire [3 : 0] s_axi_awcache
    .s_axi_awprot (m_ddr_axi_lo_cast.awprot ), // input wire [2 : 0] s_axi_awprot
    .s_axi_awvalid(m_ddr_axi_lo_cast.awvalid), // input wire s_axi_awvalid
    .s_axi_awready(m_ddr_axi_li_cast.awready), // output wire s_axi_awready
    .s_axi_wdata  (m_ddr_axi_lo_cast.wdata  ), // input wire [255 : 0] s_axi_wdata
    .s_axi_wstrb  (m_ddr_axi_lo_cast.wstrb  ), // input wire [31 : 0] s_axi_wstrb
    .s_axi_wlast  (m_ddr_axi_lo_cast.wlast  ), // input wire s_axi_wlast
    .s_axi_wvalid (m_ddr_axi_lo_cast.wvalid ), // input wire s_axi_wvalid
    .s_axi_wready (m_ddr_axi_li_cast.wready ), // output wire s_axi_wready
    .s_axi_bid    (m_ddr_axi_li_cast.bid    ), // output wire [5 : 0] s_axi_bid
    .s_axi_bresp  (m_ddr_axi_li_cast.bresp  ), // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid (m_ddr_axi_li_cast.bvalid ), // output wire s_axi_bvalid
    .s_axi_bready (m_ddr_axi_lo_cast.bready ), // input wire s_axi_bready
    .s_axi_arid   (m_ddr_axi_lo_cast.arid   ), // input wire [5 : 0] s_axi_arid
    .s_axi_araddr (m_ddr_axi_lo_cast.araddr[bram_addr_width_p-1:0]), // input wire [17 : 0] s_axi_araddr
    .s_axi_arlen  (m_ddr_axi_lo_cast.arlen  ), // input wire [7 : 0] s_axi_arlen
    .s_axi_arsize (m_ddr_axi_lo_cast.arsize ), // input wire [2 : 0] s_axi_arsize
    .s_axi_arburst(m_ddr_axi_lo_cast.arburst), // input wire [1 : 0] s_axi_arburst
    .s_axi_arlock (m_ddr_axi_lo_cast.arlock ), // input wire s_axi_arlock
    .s_axi_arcache(m_ddr_axi_lo_cast.arcache), // input wire [3 : 0] s_axi_arcache
    .s_axi_arprot (m_ddr_axi_lo_cast.arprot ), // input wire [2 : 0] s_axi_arprot
    .s_axi_arvalid(m_ddr_axi_lo_cast.arvalid), // input wire s_axi_arvalid
    .s_axi_arready(m_ddr_axi_li_cast.arready), // output wire s_axi_arready
    .s_axi_rid    (m_ddr_axi_li_cast.rid    ), // output wire [5 : 0] s_axi_rid
    .s_axi_rdata  (m_ddr_axi_li_cast.rdata  ), // output wire [255 : 0] s_axi_rdata
    .s_axi_rresp  (m_ddr_axi_li_cast.rresp  ), // output wire [1 : 0] s_axi_rresp
    .s_axi_rlast  (m_ddr_axi_li_cast.rlast  ), // output wire s_axi_rlast
    .s_axi_rvalid (m_ddr_axi_li_cast.rvalid ), // output wire s_axi_rvalid
    .s_axi_rready (m_ddr_axi_lo_cast.rready )  // input wire s_axi_rready
  );


  // tie to the axi-dma interface

  // Block ram for the AXI interface
  blk_mem_gen_1 blk_mem_xdma_inst (
    .s_aclk       (clk_i             ),
    .s_aresetn    (resetn_i          ),
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

endmodule
