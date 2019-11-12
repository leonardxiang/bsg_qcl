/**
*  mc_memory_hierarchy.v
*
*/

`include "bsg_axi_bus_pkg.vh"

module mc_memory_hierarchy
  import cl_manycore_pkg::*;
  import bsg_bladerunner_mem_cfg_pkg::*;
#(parameter data_width_p = "inv"
  , parameter addr_width_p = "inv"
  , parameter x_cord_width_p = "inv"
  , parameter y_cord_width_p = "inv"
  , parameter load_id_width_p = "inv"
  // cache
  , parameter num_cache_p = "inv"
  // AXI4
  , parameter num_axi_slot_p = "inv"
  , parameter axi_id_width_p = "inv"
  , parameter axi_addr_width_p = "inv"
  , parameter axi_data_width_p = "inv"
  , localparam link_sif_width_lp =
  `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  , localparam axi4_mosi_bus_width_lp =
  `bsg_axi4_mosi_bus_width(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p)
  , localparam axi4_miso_bus_width_lp =
  `bsg_axi4_miso_bus_width(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p)
) (
  input                                                            clk_i
  ,input                                                            reset_i
  // manycore side
  ,input        [      num_cache_p-1:0][     link_sif_width_lp-1:0] link_sif_i
  ,output       [      num_cache_p-1:0][     link_sif_width_lp-1:0] link_sif_o
  // AXI Memory Mapped interface out
  ,output       [   num_axi_slot_p-1:0][axi4_mosi_bus_width_lp-1:0] m_axi4_bus_o
  ,input        [   num_axi_slot_p-1:0][axi4_miso_bus_width_lp-1:0] m_axi4_bus_i
);

  ////////////////////////////////
  // Configurable Memory System //
  ////////////////////////////////

  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(data_width_p>>3)     ;
  localparam cache_addr_width_lp  = (addr_width_p-1+byte_offset_width_lp);

  if (mem_cfg_p == e_vcache_blocking_axi4_f1_dram
    || mem_cfg_p ==e_vcache_blocking_axi4_f1_model
    || mem_cfg_p == e_vcache_non_blocking_axi4_f1_dram
    || mem_cfg_p ==  e_vcache_non_blocking_axi4_f1_model) begin: lv1_dma

    // for now blocking and non-blocking shares the same wire, since interface is
    // the same. But it might change in the future.

    localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(cache_addr_width_lp);

    logic [num_cache_p-1:0][dma_pkt_width_lp-1:0] dma_pkt        ;
    logic [num_cache_p-1:0]                       dma_pkt_v_lo   ;
    logic [num_cache_p-1:0]                       dma_pkt_yumi_li;

    logic [num_cache_p-1:0][data_width_p-1:0] dma_data_li      ;
    logic [num_cache_p-1:0]                   dma_data_v_li    ;
    logic [num_cache_p-1:0]                   dma_data_ready_lo;

    logic [num_cache_p-1:0][data_width_p-1:0] dma_data_lo     ;
    logic [num_cache_p-1:0]                   dma_data_v_lo   ;
    logic [num_cache_p-1:0]                   dma_data_yumi_li;

  end


  // LEVEL 1
  //
  if (mem_cfg_p == e_infinite_mem) begin
    initial begin
      $fatal(0, "Not supported memcf!g\n");
    end

    // // each column has a nonsynth infinite memory
    // for (genvar i = 0; i < num_cache_p; i++) begin
    //   bsg_nonsynth_mem_infinite #(
    //     .data_width_p(data_width_p)
    //     ,.addr_width_p(addr_width_p)
    //     ,.x_cord_width_p(x_cord_width_p)
    //     ,.y_cord_width_p(y_cord_width_p)
    //     ,.load_id_width_p(load_id_width_p)
    //   ) mem_infty (
    //     .clk_i(clk_i)
    //     ,.reset_i(reset_i)
    //     // memory systems link from bsg_manycore_wrapper
    //     ,.link_sif_i(cache_link_sif_lo[i])
    //     ,.link_sif_o(cache_link_sif_li[i])
    //     // coordinates for memory system are determined by bsg_manycore_wrapper
    //     ,.my_x_i(cache_x_lo[i])
    //     ,.my_y_i(cache_y_lo[i])
    //   );
    // end

    // bind bsg_nonsynth_mem_infinite infinite_mem_profiler #(
    //   .data_width_p(data_width_p)
    //   ,.x_cord_width_p(x_cord_width_p)
    //   ,.y_cord_width_p(y_cord_width_p)
    // ) infinite_mem_prof (
    //   .*
    //   ,.global_ctr_i($root.tb.card.fpga.CL.global_ctr)
    //   ,.print_stat_v_i($root.tb.card.fpga.CL.print_stat_v_lo)
    //   ,.print_stat_tag_i($root.tb.card.fpga.CL.print_stat_tag_lo)
    // );

  end
  else if (mem_cfg_p == e_vcache_blocking_axi4_f1_dram ||
    mem_cfg_p == e_vcache_blocking_axi4_f1_model) begin : lv1_vcache_blk

    for (genvar i = 0; i < num_cache_p; i++) begin : cache

      bsg_manycore_vcache_blocking #(
        .data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.block_size_in_words_p(block_size_in_words_p)
        ,.sets_p(sets_p)
        ,.ways_p(ways_p)

        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.load_id_width_p(load_id_width_p)
      ) vcache (
        .clk_i(clk_i)
        ,.reset_i(reset_i)
        // memory systems link from bsg_manycore_wrapper
        ,.link_sif_i(cache_link_sif_lo[i])
        ,.link_sif_o(cache_link_sif_li[i])
        // coordinates for memory system are determined by bsg_manycore_wrapper
        ,.my_x_i(cache_x_lo[i])
        ,.my_y_i(cache_y_lo[i])

        ,.dma_pkt_o(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_i(lv1_dma.dma_data_li[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_o(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[i])
      );

    end : cache

    // bind bsg_cache vcache_profiler #(
    //   .data_width_p(data_width_p)
    // ) vcache_prof (
    //   .*
    //   ,.global_ctr_i($root.tb.card.fpga.CL.global_ctr)
    //   ,.print_stat_v_i($root.tb.card.fpga.CL.print_stat_v_lo)
    //   ,.print_stat_tag_i($root.tb.card.fpga.CL.print_stat_tag_lo)
    // );

  end : lv1_vcache_blk
  else if (mem_cfg_p == e_vcache_non_blocking_axi4_f1_dram ||
    mem_cfg_p == e_vcache_non_blocking_axi4_f1_model) begin : lv1_vcache_nb

    for (genvar i = 0; i < num_cache_p; i++) begin : cache
      bsg_manycore_vcache_non_blocking #(
        .data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.block_size_in_words_p(block_size_in_words_p)
        ,.sets_p(sets_p)
        ,.ways_p(ways_p)

        ,.miss_fifo_els_p(miss_fifo_els_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.load_id_width_p(load_id_width_p)
      ) vcache_nb (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(cache_link_sif_lo[i])
        ,.link_sif_o(cache_link_sif_li[i])

        ,.dma_pkt_o(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_i(lv1_dma.dma_data_li[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_o(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[i])
      );

    end : cache
  end : lv1_vcache_nb


  // LEVEL 2
  //
  if (mem_cfg_p == e_vcache_blocking_axi4_f1_dram ||
    mem_cfg_p == e_vcache_blocking_axi4_f1_model ||
    mem_cfg_p == e_vcache_non_blocking_axi4_f1_dram ||
    mem_cfg_p == e_vcache_non_blocking_axi4_f1_model ||
    mem_cfg_p == e_vcache_blocking_axi4_xbar_bram) begin: lv2_axi4_one

    bsg_cache_to_axi_hashed #(
      .addr_width_p(cache_addr_width_lp)
      ,.block_size_in_words_p(block_size_in_words_p)
      ,.data_width_p(data_width_p)
      ,.num_cache_p(num_cache_p)

      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
    ) cache_to_axi (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.dma_pkt_i(lv1_dma.dma_pkt)
      ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li)

      ,.dma_data_o(lv1_dma.dma_data_li)
      ,.dma_data_v_o(lv1_dma.dma_data_v_li)
      ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo)

      ,.dma_data_i(lv1_dma.dma_data_lo)
      ,.dma_data_v_i(lv1_dma.dma_data_v_lo)
      ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li)

      ,.axi_awid_o(m_axi4_bus_o[0].awid)
      ,.axi_awaddr_o(m_axi4_bus_o[0].awaddr)
      ,.axi_awlen_o(m_axi4_bus_o[0].awlen)
      ,.axi_awsize_o(m_axi4_bus_o[0].awsize)
      ,.axi_awburst_o(m_axi4_bus_o[0].awburst)
      ,.axi_awcache_o(m_axi4_bus_o[0].awcache)
      ,.axi_awprot_o(m_axi4_bus_o[0].awprot)
      ,.axi_awlock_o(m_axi4_bus_o[0].awlock)
      ,.axi_awvalid_o(m_axi4_bus_o[0].awvalid)
      ,.axi_awready_i(m_axi4_bus_i[0].awready)

      ,.axi_wdata_o(m_axi4_bus_o[0].wdata)
      ,.axi_wstrb_o(m_axi4_bus_o[0].wstrb)
      ,.axi_wlast_o(m_axi4_bus_o[0].wlast)
      ,.axi_wvalid_o(m_axi4_bus_o[0].wvalid)
      ,.axi_wready_i(m_axi4_bus_i[0].wready)

      ,.axi_bid_i(m_axi4_bus_i[0].bid)
      ,.axi_bresp_i(m_axi4_bus_i[0].bresp)
      ,.axi_bvalid_i(m_axi4_bus_i[0].bvalid)
      ,.axi_bready_o(m_axi4_bus_o[0].bready)

      ,.axi_arid_o(m_axi4_bus_o[0].arid)
      ,.axi_araddr_o(m_axi4_bus_o[0].araddr)
      ,.axi_arlen_o(m_axi4_bus_o[0].arlen)
      ,.axi_arsize_o(m_axi4_bus_o[0].arsize)
      ,.axi_arburst_o(m_axi4_bus_o[0].arburst)
      ,.axi_arcache_o(m_axi4_bus_o[0].arcache)
      ,.axi_arprot_o(m_axi4_bus_o[0].arprot)
      ,.axi_arlock_o(m_axi4_bus_o[0].arlock)
      ,.axi_arvalid_o(m_axi4_bus_o[0].arvalid)
      ,.axi_arready_i(m_axi4_bus_i[0].arready)

      ,.axi_rid_i(m_axi4_bus_i[0].rid)
      ,.axi_rdata_i(m_axi4_bus_i[0].rdata)
      ,.axi_rresp_i(m_axi4_bus_i[0].rresp)
      ,.axi_rlast_i(m_axi4_bus_i[0].rlast)
      ,.axi_rvalid_i(m_axi4_bus_i[0].rvalid)
      ,.axi_rready_o(m_axi4_bus_o[0].rready)
    );

    assign m_axi4_bus_o[0].awregion = 4'b0;
    assign m_axi4_bus_o[0].awqos    = 4'b0;

    assign m_axi4_bus_o[0].arregion = 4'b0;
    assign m_axi4_bus_o[0].arqos    = 4'b0;

    //synopsys translate_off
    initial begin
      assert(num_axi_slot_p == 1)
        else $fatal(0, "Do not support num_axi_slot_p > 1 in this memory configuration!\n");
    end
    // synopsys translate_on

  end : lv2_axi4_one

  else if (mem_cfg_p == e_vcache_blocking_axi4_xbar_bram ||
    mem_cfg_p == e_vcache_blocking_axi4_hbm ) begin : lv2_axi4_els

    for(genvar i = 0; i < num_cache_p; i++) begin : col_link

      bsg_cache_to_axi #(
        .addr_width_p         (cache_addr_width_lp  ),
        .block_size_in_words_p(block_size_in_words_p),
        .data_width_p         (data_width_p         ),
        .num_cache_p          (1                    ),

        .axi_id_width_p       (axi_id_width_p       ),
        .axi_addr_width_p     (axi_addr_width_p     ),
        .axi_data_width_p     (axi_data_width_p     ),
        .axi_burst_len_p      (axi_burst_len_p      )
      ) cache_to_axi (
        .clk_i           (clk_i                    ),
        .reset_i         (reset_i                  ),

        .dma_pkt_i       (lv1_dma.dma_pkt[i]          ),
        .dma_pkt_v_i     (lv1_dma.dma_pkt_v_lo[i]     ),
        .dma_pkt_yumi_o  (lv1_dma.dma_pkt_yumi_li[i]  ),

        .dma_data_o      (lv1_dma.dma_data_li[i]      ),
        .dma_data_v_o    (lv1_dma.dma_data_v_li[i]    ),
        .dma_data_ready_i(lv1_dma.dma_data_ready_lo[i]),

        .dma_data_i      (lv1_dma.dma_data_lo[i]      ),
        .dma_data_v_i    (lv1_dma.dma_data_v_lo[i]    ),
        .dma_data_yumi_o (lv1_dma.dma_data_yumi_li[i] ),

        .axi_awid_o      (m_axi4_bus_o[i].awid   ),
        .axi_awaddr_o    (m_axi4_bus_o[i].awaddr ),
        .axi_awlen_o     (m_axi4_bus_o[i].awlen  ),
        .axi_awsize_o    (m_axi4_bus_o[i].awsize ),
        .axi_awburst_o   (m_axi4_bus_o[i].awburst),
        .axi_awcache_o   (m_axi4_bus_o[i].awcache),
        .axi_awprot_o    (m_axi4_bus_o[i].awprot ),
        .axi_awlock_o    (m_axi4_bus_o[i].awlock ),
        .axi_awvalid_o   (m_axi4_bus_o[i].awvalid),
        .axi_awready_i   (m_axi4_bus_i[i].awready),

        .axi_wdata_o     (m_axi4_bus_o[i].wdata  ),
        .axi_wstrb_o     (m_axi4_bus_o[i].wstrb  ),
        .axi_wlast_o     (m_axi4_bus_o[i].wlast  ),
        .axi_wvalid_o    (m_axi4_bus_o[i].wvalid ),
        .axi_wready_i    (m_axi4_bus_i[i].wready ),

        .axi_bid_i       (m_axi4_bus_i[i].bid    ),
        .axi_bresp_i     (m_axi4_bus_i[i].bresp  ),
        .axi_bvalid_i    (m_axi4_bus_i[i].bvalid ),
        .axi_bready_o    (m_axi4_bus_o[i].bready ),

        .axi_arid_o      (m_axi4_bus_o[i].arid   ),
        .axi_araddr_o    (m_axi4_bus_o[i].araddr ),
        .axi_arlen_o     (m_axi4_bus_o[i].arlen  ),
        .axi_arsize_o    (m_axi4_bus_o[i].arsize ),
        .axi_arburst_o   (m_axi4_bus_o[i].arburst),
        .axi_arcache_o   (m_axi4_bus_o[i].arcache),
        .axi_arprot_o    (m_axi4_bus_o[i].arprot ),
        .axi_arlock_o    (m_axi4_bus_o[i].arlock ),
        .axi_arvalid_o   (m_axi4_bus_o[i].arvalid),
        .axi_arready_i   (m_axi4_bus_i[i].arready),

        .axi_rid_i       (m_axi4_bus_i[i].rid    ),
        .axi_rdata_i     (m_axi4_bus_i[i].rdata  ),
        .axi_rresp_i     (m_axi4_bus_i[i].rresp  ),
        .axi_rlast_i     (m_axi4_bus_i[i].rlast  ),
        .axi_rvalid_i    (m_axi4_bus_i[i].rvalid ),
        .axi_rready_o    (m_axi4_bus_o[i].rready )
      );

      assign m_axi4_bus_o[i].awregion = 4'b0;
      assign m_axi4_bus_o[i].awqos    = 4'b0;

      assign m_axi4_bus_o[i].arregion = 4'b0;
      assign m_axi4_bus_o[i].arqos    = 4'b0;

    end : col_link

  end // block: lv2_axi4_els

endmodule : mc_memory_hierarchy
