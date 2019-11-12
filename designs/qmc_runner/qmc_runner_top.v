/*
* qmc_runner_top
.v
*
*/

`include "bsg_defines.v"
`include "bsg_axi_bus_pkg.vh"

module qmc_runner_top 
  import cl_manycore_pkg::*;
  import bsg_cache_pkg::*;
#(
  parameter num_axi_slot_p = 1
  , parameter mc_to_io_cdc_p = 0
  , parameter mc_to_mem_cdc_p = 0
  , localparam axil_mosi_bus_width_lp = `bsg_axil_mosi_bus_width(1)
  , localparam axil_miso_bus_width_lp = `bsg_axil_miso_bus_width(1)
  , localparam axi4_mosi_bus_width_lp = `bsg_axi4_mosi_bus_width(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p)
  , localparam axi4_miso_bus_width_lp = `bsg_axi4_miso_bus_width(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p)
) (
  input                                                           clk_core_i
  ,input                                                           reset_core_i
  ,input                                                           clk_io_i
  ,input                                                           reset_io_i
  ,input  [        num_axi_slot_p-1:0]                             clk_mem_i
  ,input  [        num_axi_slot_p-1:0]                             reset_mem_i
  // AXI Lite Master Interface connections
  ,input  [axil_mosi_bus_width_lp-1:0]                             s_axil_bus_i
  ,output [axil_miso_bus_width_lp-1:0]                             s_axil_bus_o
  // AXI Memory Mapped interface out
  ,output [        num_axi_slot_p-1:0][axi4_mosi_bus_width_lp-1:0] m_axi4_bus_o
  ,input  [        num_axi_slot_p-1:0][axi4_miso_bus_width_lp-1:0] m_axi4_bus_i
);


  // -------------------------------------------------
  // AXI-Lite casting
  // -------------------------------------------------
  `declare_bsg_axil_bus_s(1, bsg_axil_mosi_bus_s, bsg_axil_miso_bus_s);
  bsg_axil_mosi_bus_s m_axil_bus_lo_cast;
  bsg_axil_miso_bus_s m_axil_bus_li_cast;

  assign m_axil_bus_lo_cast = s_axil_bus_i;
  assign s_axil_bus_o       = m_axil_bus_li_cast;


  // -------------------------------------------------
  // AXI4 casting
  // -------------------------------------------------
  `declare_bsg_axi4_bus_s(1, axi_id_width_p, axi_addr_width_p, axi_data_width_p,
                          bsg_axi4_mosi_bus_s, bsg_axi4_miso_bus_s);

  bsg_axi4_mosi_bus_s [num_axi_slot_p-1:0] axi4_mosi_cols_lo;
  bsg_axi4_miso_bus_s [num_axi_slot_p-1:0] axi4_miso_cols_li;


  // -------------------------------------------------
  // manycore signals
  // -------------------------------------------------
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);

  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_li;
  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_lo;

  bsg_manycore_link_sif_s [num_cache_p-1:0] mem_link_sif_li;
  bsg_manycore_link_sif_s [num_cache_p-1:0] mem_link_sif_lo;

  bsg_manycore_link_sif_s loader_link_sif_lo;
  bsg_manycore_link_sif_s loader_link_sif_li;

  bsg_manycore_link_sif_s axil_link_sif_li;
  bsg_manycore_link_sif_s axil_link_sif_lo;

  logic [num_cache_p-1:0][x_cord_width_p-1:0] cache_x_lo;
  logic [num_cache_p-1:0][y_cord_width_p-1:0] cache_y_lo;

  // manycore wrapper
  // 
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
    .clk_i(clk_core_i)
    ,.reset_i(reset_core_i)

    ,.cache_link_sif_i(cache_link_sif_li)
    ,.cache_link_sif_o(cache_link_sif_lo)

    ,.cache_x_o(cache_x_lo)
    ,.cache_y_o(cache_y_lo)

    ,.loader_link_sif_i(loader_link_sif_li)
    ,.loader_link_sif_o(loader_link_sif_lo)
  );


  if (mc_to_io_cdc_p == 1) begin : mc_io_cdc

    bsg_manycore_link_sif_s io_async_link_sif_li;
    bsg_manycore_link_sif_s io_async_link_sif_lo;

    assign axil_link_sif_li = async_link_sif_lo;
    assign async_link_sif_li = axil_link_sif_lo;

    bsg_manycore_link_sif_async_buffer #(
      .addr_width_p   (addr_width_p   ),
      .data_width_p   (data_width_p   ),
      .x_cord_width_p (x_cord_width_p ),
      .y_cord_width_p (y_cord_width_p ),
      .load_id_width_p(load_id_width_p),
      .fifo_els_p     (16             )
    ) async_buf (
      // core side
      .L_clk_i     (clk_core_i          ),
      .L_reset_i   (reset_core_i        ),
      .L_link_sif_i(loader_link_sif_lo  ),
      .L_link_sif_o(loader_link_sif_li  ),
      
      // AXI-L side
      .R_clk_i     (clk_io_i            ),
      .R_reset_i   (reset_io_i          ),
      .R_link_sif_i(io_async_link_sif_li),
      .R_link_sif_o(io_async_link_sif_lo)
    );

  end : mc_io_cdc
  else begin : mc_to_io

    assign axil_link_sif_li   = loader_link_sif_lo;
    assign loader_link_sif_li = axil_link_sif_lo;

  end


  if (mc_to_mem_cdc_p == 1) begin : mc_mem_cdc

    bsg_manycore_link_sif_s [num_cache_p-1:0] cache_async_link_sif_li;
    bsg_manycore_link_sif_s [num_cache_p-1:0] cache_async_link_sif_lo;

    for (genvar i = 0; i < num_cache_p; i++) begin : buf

      bsg_manycore_link_sif_async_buffer #(
        .addr_width_p   (addr_width_p   ),
        .data_width_p   (data_width_p   ),
        .x_cord_width_p (x_cord_width_p ),
        .y_cord_width_p (y_cord_width_p ),
        .load_id_width_p(load_id_width_p),
        .fifo_els_p     (16             )
      ) async_buf (
        // core side
        .L_clk_i     (clk_core_i                ),
        .L_reset_i   (reset_core_i              ),
        .L_link_sif_i(cache_link_sif_lo[i]      ),
        .L_link_sif_o(cache_link_sif_li[i]      ),

        // AXI-L side
        .R_clk_i     (clk_mem_i[i]              ),
        .R_reset_i   (reset_mem_i[i]            ),
        .R_link_sif_i(cache_async_link_sif_li[i]),
        .R_link_sif_o(cache_async_link_sif_lo[i])
      );

      assign mem_link_sif_li[i]         = cache_async_link_sif_lo[i];
      assign cache_async_link_sif_li[i] = mem_link_sif_lo[i];

    end : buf
  end : mc_mem_cdc
  else begin : mc_to_mem

    assign mem_link_sif_li   = cache_link_sif_lo;
    assign cache_link_sif_li = mem_link_sif_lo;

  end : mc_to_mem


  // Configurable Memory System
  // 
  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(data_width_p>>3)     ;
  localparam cache_addr_width_lp  = (addr_width_p-1+byte_offset_width_lp);
  `declare_bsg_cache_dma_pkt_s(cache_addr_width_lp);

  mc_memory_hierarchy #(
    .data_width_p    (data_width_p    ),
    .addr_width_p    (addr_width_p    ),
    .x_cord_width_p  (x_cord_width_p  ),
    .y_cord_width_p  (y_cord_width_p  ),
    .load_id_width_p (load_id_width_p ),
    .num_cache_p     (num_cache_p     ),
    .num_axi_slot_p  (num_axi_slot_p  ),
    .axi_id_width_p  (axi_id_width_p  ),
    .axi_addr_width_p(axi_addr_width_p),
    .axi_data_width_p(axi_data_width_p)
  ) mem_sys (
    .clk_i       (clk_i          ),
    .reset_i     (reset_mem_i    ),
    .link_sif_i  (mem_link_sif_li),
    .link_sif_o  (mem_link_sif_lo),
    .m_axi4_bus_o(m_axi4_bus_o   ),
    .m_axi4_bus_i(m_axi4_bus_i   )
  );


  // manycore link
  // 
  logic [x_cord_width_p-1:0] mcl_x_cord_li = '0;
  logic [y_cord_width_p-1:0] mcl_y_cord_li = '0;

  logic print_stat_v_lo;
  logic [data_width_p-1:0] print_stat_tag_lo;

  bsg_manycore_link_to_axil #(
    .x_cord_width_p   (x_cord_width_p   ),
    .y_cord_width_p   (y_cord_width_p   ),
    .addr_width_p     (addr_width_p     ),
    .data_width_p     (data_width_p     ),
    .max_out_credits_p(max_out_credits_p),
    .load_id_width_p  (load_id_width_p  )
  ) mcl_to_axil (
    .clk_i           (clk_io_i                  ),
    .reset_i         (reset_io_i                ),
    // axil slave interface
    .axil_awvalid_i  (m_axil_bus_lo_cast.awvalid),
    .axil_awaddr_i   (m_axil_bus_lo_cast.awaddr ),
    .axil_awready_o  (m_axil_bus_li_cast.awready),
    .axil_wvalid_i   (m_axil_bus_lo_cast.wvalid ),
    .axil_wdata_i    (m_axil_bus_lo_cast.wdata  ),
    .axil_wstrb_i    (m_axil_bus_lo_cast.wstrb  ),
    .axil_wready_o   (m_axil_bus_li_cast.wready ),
    .axil_bresp_o    (m_axil_bus_li_cast.bresp  ),
    .axil_bvalid_o   (m_axil_bus_li_cast.bvalid ),
    .axil_bready_i   (m_axil_bus_lo_cast.bready ),
    .axil_araddr_i   (m_axil_bus_lo_cast.araddr ),
    .axil_arvalid_i  (m_axil_bus_lo_cast.arvalid),
    .axil_arready_o  (m_axil_bus_li_cast.arready),
    .axil_rdata_o    (m_axil_bus_li_cast.rdata  ),
    .axil_rresp_o    (m_axil_bus_li_cast.rresp  ),
    .axil_rvalid_o   (m_axil_bus_li_cast.rvalid ),
    .axil_rready_i   (m_axil_bus_lo_cast.rready ),
    // manycore link
    .link_sif_i      (loader_link_sif_lo        ),
    .link_sif_o      (loader_link_sif_li        ),
    .my_x_i          (mcl_x_cord_li             ),
    .my_y_i          (mcl_y_cord_li             ),
    .print_stat_v_o  (print_stat_v_lo           ),
    .print_stat_tag_o(print_stat_tag_lo         )
  );

endmodule
