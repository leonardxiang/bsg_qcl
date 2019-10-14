/**
*  bsg_bladerunner_wrapper.v
*
*  top level wrapper for the bsg bladerunner design
*/

// modified header files

`include "bsg_bladerunner_pkg.v"
`include "bsg_axi_bus_pkg.vh"
`include "bsg_axi4_bus_pkg.vh"

// header file without change
`include "cl_manycore_defines.vh"
`include "bsg_manycore_packet.vh"
`include "bsg_bladerunner_rom_pkg.vh"

module bsg_bladerunner_wrapper
  import bsg_bladerunner_pkg::*;
  import bsg_bladerunner_rom_pkg::*;
#(
  parameter axi_id_width_p   = "inv"
  ,parameter axi_addr_width_p = "inv"
  ,parameter axi_data_width_p = "inv"
) (
  // System IO signals
  input                             clk_i
  ,input                             reset_i
  // AXI Lite Master Interface connections
  ,input  [                    31:0] s_axil_awaddr_i
  ,input                             s_axil_awvalid_i
  ,output                            s_axil_awready_o
  ,input  [                    31:0] s_axil_wdata_i
  ,input  [                     3:0] s_axil_wstrb_i
  ,input                             s_axil_wvalid_i
  ,output                            s_axil_wready_o
  ,output [                     1:0] s_axil_bresp_o
  ,output                            s_axil_bvalid_o
  ,input                             s_axil_bready_i
  ,input  [                    31:0] s_axil_araddr_i
  ,input                             s_axil_arvalid_i
  ,output                            s_axil_arready_o
  ,output [                    31:0] s_axil_rdata_o
  ,output [                     1:0] s_axil_rresp_o
  ,output                            s_axil_rvalid_o
  ,input                             s_axil_rready_i
  // AXI Memory Mapped interface in
  ,input  [      axi_id_width_p-1:0] s_axi_awid_i
  ,input  [    axi_addr_width_p-1:0] s_axi_awaddr_i
  ,input  [                     7:0] s_axi_awlen_i
  ,input  [                     2:0] s_axi_awsize_i
  ,input  [                     1:0] s_axi_awburst_i
  ,input                             s_axi_awvalid_i
  ,output                            s_axi_awready_o
  ,input  [    axi_data_width_p-1:0] s_axi_wdata_i
  ,input  [(axi_data_width_p/8)-1:0] s_axi_wstrb_i
  ,input                             s_axi_wlast_i
  ,input                             s_axi_wvalid_i
  ,output                            s_axi_wready_o
  ,output [      axi_id_width_p-1:0] s_axi_bid_o
  ,output [                     1:0] s_axi_bresp_o
  ,output                            s_axi_bvalid_o
  ,input                             s_axi_bready_i
  ,input  [      axi_id_width_p-1:0] s_axi_arid_i
  ,input  [    axi_addr_width_p-1:0] s_axi_araddr_i
  ,input  [                     7:0] s_axi_arlen_i
  ,input  [                     2:0] s_axi_arsize_i
  ,input  [                     1:0] s_axi_arburst_i
  ,input                             s_axi_arvalid_i
  ,output                            s_axi_arready_o
  ,output [      axi_id_width_p-1:0] s_axi_rid_o
  ,output [    axi_data_width_p-1:0] s_axi_rdata_o
  ,output [                     1:0] s_axi_rresp_o
  ,output                            s_axi_rlast_o
  ,output                            s_axi_rvalid_o
  ,input                             s_axi_rready_i
  // AXI Memory Mapped interface out
  ,output [      axi_id_width_p-1:0] m_axi_awid_o
  ,output [    axi_addr_width_p-1:0] m_axi_awaddr_o
  ,output [                     7:0] m_axi_awlen_o
  ,output [                     2:0] m_axi_awsize_o
  ,output [                     1:0] m_axi_awburst_o
  ,output                            m_axi_awvalid_o
  ,input                             m_axi_awready_i
  ,output [    axi_data_width_p-1:0] m_axi_wdata_o
  ,output [(axi_data_width_p/8)-1:0] m_axi_wstrb_o
  ,output                            m_axi_wlast_o
  ,output                            m_axi_wvalid_o
  ,input                             m_axi_wready_i
  ,input  [      axi_id_width_p-1:0] m_axi_bid_i
  ,input  [                     1:0] m_axi_bresp_i
  ,input                             m_axi_bvalid_i
  ,output                            m_axi_bready_o
  ,output [      axi_id_width_p-1:0] m_axi_arid_o
  ,output [    axi_addr_width_p-1:0] m_axi_araddr_o
  ,output [                     7:0] m_axi_arlen_o
  ,output [                     2:0] m_axi_arsize_o
  ,output [                     1:0] m_axi_arburst_o
  ,output                            m_axi_arvalid_o
  ,input                             m_axi_arready_i
  ,input  [      axi_id_width_p-1:0] m_axi_rid_i
  ,input  [    axi_data_width_p-1:0] m_axi_rdata_i
  ,input  [                     1:0] m_axi_rresp_i
  ,input                             m_axi_rlast_i
  ,input                             m_axi_rvalid_i
  ,output                            m_axi_rready_o
);


  wire clk_main_a0 = clk_i;

// -------------------------------------------------
// AXI-Lite register
// -------------------------------------------------
  `declare_bsg_axil_bus_s(1, bsg_axil_mosi_bus_s, bsg_axil_miso_bus_s);
  bsg_axil_mosi_bus_s m_axil_bus_o_cast;
  bsg_axil_miso_bus_s m_axil_bus_i_cast;

  `declare_bsg_axi4_bus_s(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p, bsg_axi4_mosi_bus_s, bsg_axi4_miso_bus_s);
  (* mark_debug = "true" *) bsg_axi4_mosi_bus_s m_axi4_mc_lo_cast, m_axi4_pcis_lo_cast, m_axi4_ddr_lo_cast;
  (* mark_debug = "true" *) bsg_axi4_miso_bus_s m_axi4_mc_li_cast, m_axi4_pcis_li_cast, m_axi4_ddr_li_cast;

  (* dont_touch = "true" *) logic axi_reg_rstn;
  lib_pipe #(.WIDTH(1), .STAGES(4)) AXI_REG_RST_N (
    .clk    (clk_main_a0 ),
    .rst_n  (1'b1        ),
    .in_bus (~reset_i    ),
    .out_bus(axi_reg_rstn)
  );

  axi_register_slice_light AXIL_OCL_REG_SLC (
    .aclk         (clk_main_a0              ),
    .aresetn      (axi_reg_rstn             ),
    .s_axi_awaddr (s_axil_awaddr_i          ),
    .s_axi_awprot (3'h0                     ),
    .s_axi_awvalid(s_axil_awvalid_i         ),
    .s_axi_awready(s_axil_awready_o         ),
    .s_axi_wdata  (s_axil_wdata_i           ),
    .s_axi_wstrb  (s_axil_wstrb_i           ),
    .s_axi_wvalid (s_axil_wvalid_i          ),
    .s_axi_wready (s_axil_wready_o          ),
    .s_axi_bresp  (s_axil_bresp_o           ),
    .s_axi_bvalid (s_axil_bvalid_o          ),
    .s_axi_bready (s_axil_bready_i          ),
    .s_axi_araddr (s_axil_araddr_i          ),
    .s_axi_arprot (3'h0                     ),
    .s_axi_arvalid(s_axil_arvalid_i         ),
    .s_axi_arready(s_axil_arready_o         ),
    .s_axi_rdata  (s_axil_rdata_o           ),
    .s_axi_rresp  (s_axil_rresp_o           ),
    .s_axi_rvalid (s_axil_rvalid_o          ),
    .s_axi_rready (s_axil_rready_i          ),
    .m_axi_awaddr (m_axil_bus_o_cast.awaddr ),
    .m_axi_awprot (                         ),
    .m_axi_awvalid(m_axil_bus_o_cast.awvalid),
    .m_axi_awready(m_axil_bus_i_cast.awready),
    .m_axi_wdata  (m_axil_bus_o_cast.wdata  ),
    .m_axi_wstrb  (m_axil_bus_o_cast.wstrb  ),
    .m_axi_wvalid (m_axil_bus_o_cast.wvalid ),
    .m_axi_wready (m_axil_bus_i_cast.wready ),
    .m_axi_bresp  (m_axil_bus_i_cast.bresp  ),
    .m_axi_bvalid (m_axil_bus_i_cast.bvalid ),
    .m_axi_bready (m_axil_bus_o_cast.bready ),
    .m_axi_araddr (m_axil_bus_o_cast.araddr ),
    .m_axi_arprot (                         ),
    .m_axi_arvalid(m_axil_bus_o_cast.arvalid),
    .m_axi_arready(m_axil_bus_i_cast.arready),
    .m_axi_rdata  (m_axil_bus_i_cast.rdata  ),
    .m_axi_rresp  (m_axil_bus_i_cast.rresp  ),
    .m_axi_rvalid (m_axil_bus_i_cast.rvalid ),
    .m_axi_rready (m_axil_bus_o_cast.rready )
  );


  (* dont_touch = "true" *) logic rst_main_n_sync;
  lib_pipe #(.WIDTH(1), .STAGES(4)) MC_RST_N (
    .clk    (clk_main_a0 ),
    .rst_n  (1'b1        ),
    .in_bus (~reset_i    ),
    .out_bus(rst_main_n_sync)
  );


  // manycore wrapper signals
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);

  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_li;
  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_lo;

  logic [num_cache_p-1:0][x_cord_width_p-1:0] cache_x_lo;
  logic [num_cache_p-1:0][y_cord_width_p-1:0] cache_y_lo;

  bsg_manycore_link_sif_s loader_link_sif_lo;
  bsg_manycore_link_sif_s loader_link_sif_li;

  bsg_manycore_wrapper #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.num_cache_p(num_cache_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(block_size_in_words_p)
    ,.vcache_sets_p(sets_p)
    ,.branch_trace_en_p(branch_trace_en_p)
  ) manycore_wrapper (
    .clk_i(clk_main_a0)
    ,.reset_i(~rst_main_n_sync)

    ,.cache_link_sif_i(cache_link_sif_li)
    ,.cache_link_sif_o(cache_link_sif_lo)

    ,.cache_x_o(cache_x_lo)
    ,.cache_y_o(cache_y_lo)

    ,.loader_link_sif_i(loader_link_sif_li)
    ,.loader_link_sif_o(loader_link_sif_lo)
  );


  // configurable memory system
  //
  memory_system #(
    .mem_cfg_p(mem_cfg_p)

    ,.bsg_global_x_p(num_tiles_x_p)
    ,.bsg_global_y_p(num_tiles_y_p)

    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)

    ,.block_size_in_words_p(block_size_in_words_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)

    ,.axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)

  ) memsys (
    .clk_i(clk_main_a0)
    ,.reset_i(~rst_main_n_sync)

    ,.link_sif_i(cache_link_sif_lo)
    ,.link_sif_o(cache_link_sif_li)

    ,.axi_awid_o    (m_axi4_mc_lo_cast.awid)
    ,.axi_awaddr_o  (m_axi4_mc_lo_cast.awaddr)
    ,.axi_awlen_o   (m_axi4_mc_lo_cast.awlen)
    ,.axi_awsize_o  (m_axi4_mc_lo_cast.awsize)
    ,.axi_awburst_o (m_axi4_mc_lo_cast.awburst)
    ,.axi_awcache_o (m_axi4_mc_lo_cast.awcache)
    ,.axi_awprot_o  (m_axi4_mc_lo_cast.awprot)
    ,.axi_awlock_o  (m_axi4_mc_lo_cast.awlock)
    ,.axi_awvalid_o (m_axi4_mc_lo_cast.awvalid)
    ,.axi_awready_i (m_axi4_mc_li_cast.awready)

    ,.axi_wdata_o   (m_axi4_mc_lo_cast.wdata)
    ,.axi_wstrb_o   (m_axi4_mc_lo_cast.wstrb)
    ,.axi_wlast_o   (m_axi4_mc_lo_cast.wlast)
    ,.axi_wvalid_o  (m_axi4_mc_lo_cast.wvalid)
    ,.axi_wready_i  (m_axi4_mc_li_cast.wready)

    ,.axi_bid_i     (m_axi4_mc_li_cast.bid)
    ,.axi_bresp_i   (m_axi4_mc_li_cast.bresp)
    ,.axi_bvalid_i  (m_axi4_mc_li_cast.bvalid)
    ,.axi_bready_o  (m_axi4_mc_lo_cast.bready)

    ,.axi_arid_o    (m_axi4_mc_lo_cast.arid)
    ,.axi_araddr_o  (m_axi4_mc_lo_cast.araddr)
    ,.axi_arlen_o   (m_axi4_mc_lo_cast.arlen)
    ,.axi_arsize_o  (m_axi4_mc_lo_cast.arsize)
    ,.axi_arburst_o (m_axi4_mc_lo_cast.arburst)
    ,.axi_arcache_o (m_axi4_mc_lo_cast.arcache)
    ,.axi_arprot_o  (m_axi4_mc_lo_cast.arprot)
    ,.axi_arlock_o  (m_axi4_mc_lo_cast.arlock)
    ,.axi_arvalid_o (m_axi4_mc_lo_cast.arvalid)
    ,.axi_arready_i (m_axi4_mc_li_cast.arready)

    ,.axi_rid_i     (m_axi4_mc_li_cast.rid)
    ,.axi_rdata_i   (m_axi4_mc_li_cast.rdata)
    ,.axi_rresp_i   (m_axi4_mc_li_cast.rresp)
    ,.axi_rlast_i   (m_axi4_mc_li_cast.rlast)
    ,.axi_rvalid_i  (m_axi4_mc_li_cast.rvalid)
    ,.axi_rready_o  (m_axi4_mc_lo_cast.rready)
  );

  assign m_axi4_mc_lo_cast.awregion = 4'b0;
  assign m_axi4_mc_lo_cast.awqos = 4'b0;

  assign m_axi4_mc_lo_cast.arregion = 4'b0;
  assign m_axi4_mc_lo_cast.arqos = 4'b0;


  // manycore link

  logic [x_cord_width_p-1:0] mcl_x_cord_lp = '0;
  logic [y_cord_width_p-1:0] mcl_y_cord_lp = '0;

  logic print_stat_v_lo;
  logic [data_width_p-1:0] print_stat_tag_lo;

  axil_to_mcl #(
    .num_mcl_p        (1                )
    ,.num_tiles_x_p    (num_tiles_x_p    )
    ,.num_tiles_y_p    (num_tiles_y_p    )
    ,.addr_width_p     (addr_width_p     )
    ,.data_width_p     (data_width_p     )
    ,.x_cord_width_p   (x_cord_width_p   )
    ,.y_cord_width_p   (y_cord_width_p   )
    ,.load_id_width_p  (load_id_width_p  )
    ,.max_out_credits_p(max_out_credits_p)
  ) axil_to_mcl_inst (
    .clk_i             (clk_main_a0       )
    ,.reset_i           (~rst_main_n_sync  )

    // axil slave interface
    ,.s_axil_mcl_awvalid(m_axil_bus_o_cast.awvalid)
    ,.s_axil_mcl_awaddr (m_axil_bus_o_cast.awaddr )
    ,.s_axil_mcl_awready(m_axil_bus_i_cast.awready)
    ,.s_axil_mcl_wvalid (m_axil_bus_o_cast.wvalid )
    ,.s_axil_mcl_wdata  (m_axil_bus_o_cast.wdata  )
    ,.s_axil_mcl_wstrb  (m_axil_bus_o_cast.wstrb  )
    ,.s_axil_mcl_wready (m_axil_bus_i_cast.wready )
    ,.s_axil_mcl_bresp  (m_axil_bus_i_cast.bresp  )
    ,.s_axil_mcl_bvalid (m_axil_bus_i_cast.bvalid )
    ,.s_axil_mcl_bready (m_axil_bus_o_cast.bready )
    ,.s_axil_mcl_araddr (m_axil_bus_o_cast.araddr )
    ,.s_axil_mcl_arvalid(m_axil_bus_o_cast.arvalid)
    ,.s_axil_mcl_arready(m_axil_bus_i_cast.arready)
    ,.s_axil_mcl_rdata  (m_axil_bus_i_cast.rdata  )
    ,.s_axil_mcl_rresp  (m_axil_bus_i_cast.rresp  )
    ,.s_axil_mcl_rvalid (m_axil_bus_i_cast.rvalid )
    ,.s_axil_mcl_rready (m_axil_bus_o_cast.rready )

    // manycore link
    ,.link_sif_i        (loader_link_sif_lo)
    ,.link_sif_o        (loader_link_sif_li)
    ,.my_x_i            (mcl_x_cord_lp     )
    ,.my_y_i            (mcl_y_cord_lp     )

    ,.print_stat_v_o(print_stat_v_lo)
    ,.print_stat_tag_o(print_stat_tag_lo)
  );


 // --------------------------------------------------------------
  // AXI4 PCIS from shell
  // --------------------------------------------------------------
  //  mosi signals
  assign m_axi4_pcis_lo_cast.awid     = s_axi_awid_i;
  assign m_axi4_pcis_lo_cast.awaddr   = s_axi_awaddr_i;
  assign m_axi4_pcis_lo_cast.awlen    = s_axi_awlen_i;
  assign m_axi4_pcis_lo_cast.awsize   = s_axi_awsize_i;
  assign m_axi4_pcis_lo_cast.awburst  = s_axi_awburst_i;
  assign m_axi4_pcis_lo_cast.awlock   = '0;
  assign m_axi4_pcis_lo_cast.awcache  = '0;
  assign m_axi4_pcis_lo_cast.awprot   = '0;
  assign m_axi4_pcis_lo_cast.awqos    = '0;
  assign m_axi4_pcis_lo_cast.awregion = '0;
  assign m_axi4_pcis_lo_cast.awvalid  = s_axi_awvalid_i;
  assign m_axi4_pcis_lo_cast.wdata    = s_axi_wdata_i;
  assign m_axi4_pcis_lo_cast.wstrb    = s_axi_wstrb_i;
  assign m_axi4_pcis_lo_cast.wlast    = s_axi_wlast_i;
  assign m_axi4_pcis_lo_cast.wvalid   = s_axi_wvalid_i;
  assign m_axi4_pcis_lo_cast.bready   = s_axi_bready_i;
  assign m_axi4_pcis_lo_cast.arid     = s_axi_arid_i;
  assign m_axi4_pcis_lo_cast.araddr   = s_axi_araddr_i;
  assign m_axi4_pcis_lo_cast.arlen    = s_axi_arlen_i;
  assign m_axi4_pcis_lo_cast.arsize   = s_axi_arsize_i;
  assign m_axi4_pcis_lo_cast.arburst  = s_axi_arburst_i;
  assign m_axi4_pcis_lo_cast.arlock   = '0;
  assign m_axi4_pcis_lo_cast.arcache  = '0;
  assign m_axi4_pcis_lo_cast.arprot   = '0;
  assign m_axi4_pcis_lo_cast.arqos    = '0;
  assign m_axi4_pcis_lo_cast.arregion = '0;
  assign m_axi4_pcis_lo_cast.arvalid  = s_axi_arvalid_i;
  assign m_axi4_pcis_lo_cast.rready   = s_axi_rready_i;
  //  miso signals
  assign s_axi_awready_o = m_axi4_pcis_li_cast.awready;
  assign s_axi_wready_o  = m_axi4_pcis_li_cast.wready;
  assign s_axi_bid_o     = m_axi4_pcis_li_cast.bid;
  assign s_axi_bresp_o   = m_axi4_pcis_li_cast.bresp;
  assign s_axi_bvalid_o  = m_axi4_pcis_li_cast.bvalid;
  assign s_axi_arready_o = m_axi4_pcis_li_cast.arready;
  assign s_axi_rid_o     = m_axi4_pcis_li_cast.rid;
  assign s_axi_rdata_o   = m_axi4_pcis_li_cast.rdata;
  assign s_axi_rresp_o   = m_axi4_pcis_li_cast.rresp;
  assign s_axi_rlast_o   = m_axi4_pcis_li_cast.rlast;
  assign s_axi_rvalid_o  = m_axi4_pcis_li_cast.rvalid;


  (* dont_touch = "true" *) logic axi4_mux_rstn;
  lib_pipe #(.WIDTH(1), .STAGES(4)) AXI4_MUX_RST_N (
    .clk    (clk_main_a0  ),
    .rst_n  (1'b1         ),
    .in_bus (~reset_i     ),
    .out_bus(axi4_mux_rstn)
  );

  localparam slot_num_lp = 2;
  axi4_mux #(
    .slot_num_p  (slot_num_lp     ),
    .id_width_p  (axi_id_width_p  ),
    .addr_width_p(axi_addr_width_p),
    .data_width_p(axi_data_width_p)
  ) axi4_multiplexer (
    .clk_i       (clk_main_a0                             ),
    .reset_i     (~axi4_mux_rstn                          ),
    .s_axi4_mux_i({m_axi4_mc_lo_cast, m_axi4_pcis_lo_cast}),
    .s_axi4_mux_o({m_axi4_mc_li_cast, m_axi4_pcis_li_cast}),
    .m_axi4_bus_o(m_axi4_ddr_lo_cast                      ),
    .m_axi4_bus_i(m_axi4_ddr_li_cast                      )
  );

  //  mosi signals
  assign m_axi_awid_o    = m_axi4_ddr_lo_cast.awid;
  assign m_axi_awaddr_o  = m_axi4_ddr_lo_cast.awaddr;
  assign m_axi_awlen_o   = m_axi4_ddr_lo_cast.awlen;
  assign m_axi_awsize_o  = m_axi4_ddr_lo_cast.awsize;
  assign m_axi_awburst_o = m_axi4_ddr_lo_cast.awburst;
  assign m_axi_awvalid_o = m_axi4_ddr_lo_cast.awvalid;
  assign m_axi_wdata_o   = m_axi4_ddr_lo_cast.wdata;
  assign m_axi_wstrb_o   = m_axi4_ddr_lo_cast.wstrb;
  assign m_axi_wlast_o   = m_axi4_ddr_lo_cast.wlast;
  assign m_axi_wvalid_o  = m_axi4_ddr_lo_cast.wvalid;
  assign m_axi_bready_o  = m_axi4_ddr_lo_cast.bready;
  assign m_axi_arid_o    = m_axi4_ddr_lo_cast.arid;
  assign m_axi_araddr_o  = m_axi4_ddr_lo_cast.araddr;
  assign m_axi_arlen_o   = m_axi4_ddr_lo_cast.arlen;
  assign m_axi_arsize_o  = m_axi4_ddr_lo_cast.arsize;
  assign m_axi_arburst_o = m_axi4_ddr_lo_cast.arburst;
  assign m_axi_arvalid_o = m_axi4_ddr_lo_cast.arvalid;
  assign m_axi_rready_o  = m_axi4_ddr_lo_cast.rready;

  //  miso signals
  assign m_axi4_ddr_li_cast.awready = m_axi_awready_i;
  assign m_axi4_ddr_li_cast.wready  = m_axi_wready_i;
  assign m_axi4_ddr_li_cast.bid     = m_axi_bid_i;
  assign m_axi4_ddr_li_cast.bresp   = m_axi_bresp_i;
  assign m_axi4_ddr_li_cast.bvalid  = m_axi_bvalid_i;
  assign m_axi4_ddr_li_cast.arready = m_axi_arready_i;
  assign m_axi4_ddr_li_cast.rid     = m_axi_rid_i;
  assign m_axi4_ddr_li_cast.rdata   = m_axi_rdata_i;
  assign m_axi4_ddr_li_cast.rresp   = m_axi_rresp_i;
  assign m_axi4_ddr_li_cast.rlast   = m_axi_rlast_i;
  assign m_axi4_ddr_li_cast.rvalid  = m_axi_rvalid_i;

endmodule : bsg_bladerunner_wrapper
