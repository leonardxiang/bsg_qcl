// ----------------------------------------------------------------------------
//  Example Project    : The Xilinx PCI Express DMA 4.1
// ----------------------------------------------------------------------------

module xilinx_dma_pcie_ep #(
  // -------------------------------------------
  // Project    : The Xilinx PCI Express DMA
  // File       : xilinx_dma_pcie_ep.sv
  // Version    : 4.1
  // -------------------------------------------
  parameter  PL_LINK_CAP_MAX_LINK_WIDTH = 4           , // 1- X1; 2 - X2; 4 - X4; 8 - X8
  // parameter PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
  parameter  PL_LINK_CAP_MAX_LINK_SPEED = 1           , // 1- GEN1; 2 - GEN2; 4 - GEN3
  parameter  C_DATA_WIDTH               = 64          ,
  localparam C_S_AXI_DATA_WIDTH         = C_DATA_WIDTH,
  localparam C_M_AXI_DATA_WIDTH         = C_DATA_WIDTH,
  parameter  C_M_AXI_ID_WIDTH           = 4           ,
  localparam C_M_AXI_ADDR_WIDTH         = 64
  // parameter EXT_PIPE_SIM                        = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
  // parameter C_ROOT_PORT                         = "FALSE",      // PCIe block is in root port mode
  // parameter C_DEVICE_NUMBER                     = 0,            // Device number for Root Port configurations only
  // parameter AXIS_CCIX_RX_TDATA_WIDTH     = 256,
  // parameter AXIS_CCIX_TX_TDATA_WIDTH     = 256,
  // parameter AXIS_CCIX_RX_TUSER_WIDTH     = 46,
  // parameter AXIS_CCIX_TX_TUSER_WIDTH     = 46
) (
  output [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0] pci_exp_txp    ,
  output [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0] pci_exp_txn    ,
  input  [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0] pci_exp_rxp    ,
  input  [(PL_LINK_CAP_MAX_LINK_WIDTH-1):0] pci_exp_rxn    ,
  //VU9P_TUL_EX_String= FALSE
  input                                     sys_clk_p_i    ,
  input                                     sys_clk_n_i    ,
  input                                     sys_rst_n_i    ,
  output                                    sys_rst_n_buf_o,
  // user-defined signals
  output                                    user_clk_o     ,
  output                                    user_resetn_o  ,
  output                                    user_link_up_o ,
  output [                             3:0] leds_o         ,
  // AXI Lite Master Interface connections
  output [                            31:0] m_axil_awaddr  ,
  output                                    m_axil_awvalid ,
  input                                     m_axil_awready ,
  output [                            31:0] m_axil_wdata   ,
  output [                             3:0] m_axil_wstrb   ,
  output                                    m_axil_wvalid  ,
  input                                     m_axil_wready  ,
  input  [                             1:0] m_axil_bresp   ,
  input                                     m_axil_bvalid  ,
  output                                    m_axil_bready  ,
  output [                            31:0] m_axil_araddr  ,
  output                                    m_axil_arvalid ,
  input                                     m_axil_arready ,
  input  [                            31:0] m_axil_rdata   ,
  input  [                             1:0] m_axil_rresp   ,
  input                                     m_axil_rvalid  ,
  output                                    m_axil_rready  ,
  //VU9P_TUL_EX_String= FALSE
  // AXI Memory Mapped interface
  output [            C_M_AXI_ID_WIDTH-1:0] m_axi_awid     ,
  output [          C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr   ,
  output [                             7:0] m_axi_awlen    ,
  output [                             2:0] m_axi_awsize   ,
  output [                             1:0] m_axi_awburst  ,
  output                                    m_axi_awvalid  ,
  input                                     m_axi_awready  ,
  output [          C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata    ,
  output [      (C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb    ,
  output                                    m_axi_wlast    ,
  output                                    m_axi_wvalid   ,
  input                                     m_axi_wready   ,
  input  [            C_M_AXI_ID_WIDTH-1:0] m_axi_bid      ,
  input  [                             1:0] m_axi_bresp    ,
  input                                     m_axi_bvalid   ,
  output                                    m_axi_bready   ,
  output [            C_M_AXI_ID_WIDTH-1:0] m_axi_arid     ,
  output [          C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr   ,
  output [                             7:0] m_axi_arlen    ,
  output [                             2:0] m_axi_arsize   ,
  output [                             1:0] m_axi_arburst  ,
  output                                    m_axi_arvalid  ,
  input                                     m_axi_arready  ,
  input  [            C_M_AXI_ID_WIDTH-1:0] m_axi_rid      ,
  input  [          C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata    ,
  input  [                             1:0] m_axi_rresp    ,
  input                                     m_axi_rlast    ,
  input                                     m_axi_rvalid   ,
  output                                    m_axi_rready   ,
  // AXI stream interface for the CQ forwarding
  output [            C_M_AXI_ID_WIDTH-1:0] m_axib_awid    ,
  // 18:0
  output [          C_M_AXI_ADDR_WIDTH-1:0] m_axib_awaddr  ,
  output [                             7:0] m_axib_awlen   ,
  output [                             2:0] m_axib_awsize  ,
  output [                             1:0] m_axib_awburst ,
  output                                    m_axib_awvalid ,
  input                                     m_axib_awready ,
  output [          C_M_AXI_DATA_WIDTH-1:0] m_axib_wdata   ,
  output [      (C_M_AXI_DATA_WIDTH/8)-1:0] m_axib_wstrb   ,
  output                                    m_axib_wlast   ,
  output                                    m_axib_wvalid  ,
  input                                     m_axib_wready  ,
  input  [            C_M_AXI_ID_WIDTH-1:0] m_axib_bid     ,
  input  [                             1:0] m_axib_bresp   ,
  input                                     m_axib_bvalid  ,
  output                                    m_axib_bready  ,
  output [            C_M_AXI_ID_WIDTH-1:0] m_axib_arid    ,
  // 18:0
  output [          C_M_AXI_ADDR_WIDTH-1:0] m_axib_araddr  ,
  output [                             7:0] m_axib_arlen   ,
  output [                             2:0] m_axib_arsize  ,
  output [                             1:0] m_axib_arburst ,
  output                                    m_axib_arvalid ,
  input                                     m_axib_arready ,
  input  [            C_M_AXI_ID_WIDTH-1:0] m_axib_rid     ,
  input  [          C_M_AXI_DATA_WIDTH-1:0] m_axib_rdata   ,
  input  [                             1:0] m_axib_rresp   ,
  input                                     m_axib_rlast   ,
  input                                     m_axib_rvalid  ,
  output                                    m_axib_rready
);

   //-----------------------------------------------------------------------------------------------------------------------


   // Local Parameters derived from user selection
  // localparam integer USER_CLK_FREQ = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
  localparam TCQ                = 1                                             ;
  // localparam C_S_AXI_ID_WIDTH   = 4                                             ;
  // localparam C_M_AXI_ID_WIDTH   = 4           ;
  // localparam C_S_AXI_DATA_WIDTH = C_DATA_WIDTH;
  // localparam C_M_AXI_DATA_WIDTH = C_DATA_WIDTH;
  // localparam C_S_AXI_ADDR_WIDTH = 64                                            ;
  // localparam C_M_AXI_ADDR_WIDTH = 64;
  localparam C_NUM_USR_IRQ      = 1 ;

  wire user_lnk_up;

  assign user_link_up_o = user_lnk_up;

   //----------------------------------------------------------------------------------------------------------------//
   //  AXI Interface                                                                                                 //
   //----------------------------------------------------------------------------------------------------------------//

  wire user_clk   ;
  wire user_resetn;

  assign user_clk_o = user_clk;
  assign user_resetn_o = user_resetn;
  // // Wires for Avery HOT/WARM and COLD RESET
  //  wire              avy_sys_rst_n_c;
  //  wire              avy_cfg_hot_reset_out;
  //  reg               avy_sys_rst_n_g;
  //  reg               avy_cfg_hot_reset_out_g;
  //  assign avy_sys_rst_n_c = avy_sys_rst_n_g;
  //  assign avy_cfg_hot_reset_out = avy_cfg_hot_reset_out_g;
  //  initial begin
  //     avy_sys_rst_n_g = 1;
  //     avy_cfg_hot_reset_out_g =0;
  //  end

  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//

  wire sys_clk    ;
  wire sys_rst_n_c;

  assign sys_rst_n_buf_o = sys_rst_n_c;

  // User Clock LED Heartbeat
  reg [25:0]            user_clk_heartbeat;
  // reg [((2*C_NUM_USR_IRQ)-1):0]    usr_irq_function_number=0;
  reg  [C_NUM_USR_IRQ-1:0] usr_irq_req = 0;
  wire [C_NUM_USR_IRQ-1:0] usr_irq_ack    ;

///////////////////////////////////////////////////////////////////////////////
  //-- AXI Master Write Address Channel
  wire [                   2:0] m_axi_awprot ;
  wire [                   3:0] m_axi_awcache;
  wire                          m_axi_awlock ;
  //-- AXI Master Read Address Channel
  wire [                   2:0] m_axi_arprot ;
  wire                          m_axi_arlock ;
  wire [                   3:0] m_axi_arcache;

  ///////////////////////////////////////////////////////////////////////////////
  // CQ forwarding port to BARAM
  wire [                   2:0] m_axib_awprot ;
  wire [                   3:0] m_axib_awcache;
  wire                          m_axib_awlock ;
  //-- AXI Master Read Address Channel
  wire [2:0]                    m_axib_arprot ;
  wire                          m_axib_arlock ;
  wire [3:0]                    m_axib_arcache;
  ////////////////////////////////////////////////////////////////////////////////

    wire [2:0] msi_vector_width;
    wire       msi_enable      ;
  // wire [5:0]                          cfg_ltssm_state;

  // Ref clock buffer
  IBUFDS_GTE4 # (.REFCLK_HROW_CK_SEL(2'b00)) refclk_ibuf (.O(sys_clk_gt), .ODIV2(sys_clk), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));
  // Reset buffer
  IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));

  // Core Top Level Wrapper
  xdma_0 xdma_0_i
     (
    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//
    .sys_rst_n       ( sys_rst_n_c ),
    .sys_clk         ( sys_clk ),
    .sys_clk_gt      ( sys_clk_gt),

    // Tx
    .pci_exp_txn     ( pci_exp_txn ),
    .pci_exp_txp     ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn     ( pci_exp_rxn ),
    .pci_exp_rxp     ( pci_exp_rxp ),

     // AXI MM Interface
    .m_axi_awid      (m_axi_awid  ),
    .m_axi_awaddr    (m_axi_awaddr),
    .m_axi_awlen     (m_axi_awlen),
    .m_axi_awsize    (m_axi_awsize),
    .m_axi_awburst   (m_axi_awburst),
    .m_axi_awprot    (m_axi_awprot),
    .m_axi_awvalid   (m_axi_awvalid),
    .m_axi_awready   (m_axi_awready),
    .m_axi_awlock    (m_axi_awlock),
    .m_axi_awcache   (m_axi_awcache),
    .m_axi_wdata     (m_axi_wdata),
    .m_axi_wstrb     (m_axi_wstrb),
    .m_axi_wlast     (m_axi_wlast),
    .m_axi_wvalid    (m_axi_wvalid),
    .m_axi_wready    (m_axi_wready),
    .m_axi_bid       (m_axi_bid),
    .m_axi_bresp     (m_axi_bresp),
    .m_axi_bvalid    (m_axi_bvalid),
    .m_axi_bready    (m_axi_bready),
    .m_axi_arid      (m_axi_arid),
    .m_axi_araddr    (m_axi_araddr),
    .m_axi_arlen     (m_axi_arlen),
    .m_axi_arsize    (m_axi_arsize),
    .m_axi_arburst   (m_axi_arburst),
    .m_axi_arprot    (m_axi_arprot),
    .m_axi_arvalid   (m_axi_arvalid),
    .m_axi_arready   (m_axi_arready),
    .m_axi_arlock    (m_axi_arlock),
    .m_axi_arcache   (m_axi_arcache),
    .m_axi_rid       (m_axi_rid),
    .m_axi_rdata     (m_axi_rdata),
    .m_axi_rresp     (m_axi_rresp),
    .m_axi_rlast     (m_axi_rlast),
    .m_axi_rvalid    (m_axi_rvalid),
    .m_axi_rready    (m_axi_rready),
     // CQ Bypass ports
    .m_axib_awid      (m_axib_awid),
    .m_axib_awaddr    (m_axib_awaddr),
    .m_axib_awlen     (m_axib_awlen),
    .m_axib_awsize    (m_axib_awsize),
    .m_axib_awburst   (m_axib_awburst),
    .m_axib_awprot    (m_axib_awprot),
    .m_axib_awvalid   (m_axib_awvalid),
    .m_axib_awready   (m_axib_awready),
    .m_axib_awlock    (m_axib_awlock),
    .m_axib_awcache   (m_axib_awcache),
    .m_axib_wdata     (m_axib_wdata),
    .m_axib_wstrb     (m_axib_wstrb),
    .m_axib_wlast     (m_axib_wlast),
    .m_axib_wvalid    (m_axib_wvalid),
    .m_axib_wready    (m_axib_wready),
    .m_axib_bid       (m_axib_bid),
    .m_axib_bresp     (m_axib_bresp),
    .m_axib_bvalid    (m_axib_bvalid),
    .m_axib_bready    (m_axib_bready),
    .m_axib_arid      (m_axib_arid),
    .m_axib_araddr    (m_axib_araddr),
    .m_axib_arlen     (m_axib_arlen),
    .m_axib_arsize    (m_axib_arsize),
    .m_axib_arburst   (m_axib_arburst),
    .m_axib_arprot    (m_axib_arprot),
    .m_axib_arvalid   (m_axib_arvalid),
    .m_axib_arready   (m_axib_arready),
    .m_axib_arlock    (m_axib_arlock),
    .m_axib_arcache   (m_axib_arcache),
    .m_axib_rid       (m_axib_rid),
    .m_axib_rdata     (m_axib_rdata),
    .m_axib_rresp     (m_axib_rresp),
    .m_axib_rlast     (m_axib_rlast),
    .m_axib_rvalid    (m_axib_rvalid),
    .m_axib_rready    (m_axib_rready),
    // LITE interface
    //-- AXI Master Write Address Channel
    .m_axil_awaddr    (m_axil_awaddr),
    .m_axil_awprot    (m_axil_awprot),
    .m_axil_awvalid   (m_axil_awvalid),
    .m_axil_awready   (m_axil_awready),
    //-- AXI Master Write Data Channel
    .m_axil_wdata     (m_axil_wdata),
    .m_axil_wstrb     (m_axil_wstrb),
    .m_axil_wvalid    (m_axil_wvalid),
    .m_axil_wready    (m_axil_wready),
    //-- AXI Master Write Response Channel
    .m_axil_bvalid    (m_axil_bvalid),
    .m_axil_bresp     (m_axil_bresp),
    .m_axil_bready    (m_axil_bready),
    //-- AXI Master Read Address Channel
    .m_axil_araddr    (m_axil_araddr),
    .m_axil_arprot    (m_axil_arprot),
    .m_axil_arvalid   (m_axil_arvalid),
    .m_axil_arready   (m_axil_arready),
    .m_axil_rdata     (m_axil_rdata),
    //-- AXI Master Read Data Channel
    .m_axil_rresp     (m_axil_rresp),
    .m_axil_rvalid    (m_axil_rvalid),
    .m_axil_rready    (m_axil_rready),


    .usr_irq_req       (usr_irq_req),
    .usr_irq_ack       (usr_irq_ack),
    .msi_enable        (msi_enable),
    .msi_vector_width  (msi_vector_width),

   // Config managemnet interface
    .cfg_mgmt_addr  ( 19'b0 ),
    .cfg_mgmt_write ( 1'b0 ),
    .cfg_mgmt_write_data ( 32'b0 ),
    .cfg_mgmt_byte_enable ( 4'b0 ),
    .cfg_mgmt_read  ( 1'b0 ),
    .cfg_mgmt_read_data (),
    .cfg_mgmt_read_write_done (),

    //-- AXI Global
    .axi_aclk        ( user_clk ),
    .axi_aresetn     ( user_resetn ),

    .user_lnk_up     ( user_lnk_up )
  );


  // The sys_rst_n input is active low based on the core configuration
  assign sys_resetn = sys_rst_n;

  // Create a Clock Heartbeat
  always_ff @(posedge user_clk) begin
    if(!sys_resetn) begin
      user_clk_heartbeat <= #TCQ 26'd0;
    end else begin
      user_clk_heartbeat <= #TCQ user_clk_heartbeat + 1'b1;
    end
  end

  // LEDs for observation
  assign leds_o[0] = sys_resetn;
  assign leds_o[1] = user_resetn;
  assign leds_o[2] = user_lnk_up;
  assign leds_o[3] = user_clk_heartbeat[25];

endmodule
