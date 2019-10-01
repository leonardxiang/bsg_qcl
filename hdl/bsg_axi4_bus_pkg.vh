`ifndef BSG_AXI4_BUS_PKG_VH
`define BSG_AXI4_BUS_PKG_VH

// -----------------------------------------------------------
// Axi4-full interface (optional signals are disabled
// -----------------------------------------------------------
`define declare_bsg_axi4_bus_s(slot_num_lp, id_width_p, addr_width_p, data_width_p, mosi_struct_name, miso_struct_name) \
typedef struct packed { \
  logic [  slot_num_lp*id_width_p-1:0] awid    ; \
  logic [slot_num_lp*addr_width_p-1:0] awaddr  ; \
  logic [           slot_num_lp*8-1:0] awlen   ; \
  logic [           slot_num_lp*3-1:0] awsize  ; \
  logic [           slot_num_lp*2-1:0] awburst ; \
  logic [             slot_num_lp-1:0] awlock  ; \
  logic [           slot_num_lp*4-1:0] awcache ; \
  logic [           slot_num_lp*3-1:0] awprot  ; \
  logic [           slot_num_lp*4-1:0] awqos   ; \
  logic [           slot_num_lp*4-1:0] awregion; \
  logic [             slot_num_lp-1:0] awvalid ; \
  \
  logic [  slot_num_lp*data_width_p-1:0] wdata ; \
  logic [slot_num_lp*data_width_p/8-1:0] wstrb ; \
  logic [               slot_num_lp-1:0] wlast ; \
  logic [               slot_num_lp-1:0] wvalid; \
  \
  logic [slot_num_lp-1:0] bready; \
  \
  logic [  slot_num_lp*id_width_p-1:0] arid    ; \
  logic [slot_num_lp*addr_width_p-1:0] araddr  ; \
  logic [           slot_num_lp*8-1:0] arlen   ; \
  logic [           slot_num_lp*3-1:0] arsize  ; \
  logic [           slot_num_lp*2-1:0] arburst ; \
  logic [             slot_num_lp-1:0] arlock  ; \
  logic [           slot_num_lp*4-1:0] arcache ; \
  logic [           slot_num_lp*3-1:0] arprot  ; \
  logic [           slot_num_lp*4-1:0] arqos   ; \
  logic [           slot_num_lp*4-1:0] arregion; \
  logic [             slot_num_lp-1:0] arvalid ; \
  \
  logic [slot_num_lp-1:0] rready; \
} mosi_struct_name; \
\
typedef struct packed { \
  logic [slot_num_lp-1:0] awready; \
  \
  logic [slot_num_lp-1:0] wready; \
  \
  logic [slot_num_lp*id_width_p-1:0] bid   ; \
  logic [         slot_num_lp*2-1:0] bresp ; \
  logic [           slot_num_lp-1:0] bvalid; \
  \
  logic [slot_num_lp-1:0] arready; \
  \
  logic [  slot_num_lp*id_width_p-1:0] rid   ; \
  logic [slot_num_lp*data_width_p-1:0] rdata ; \
  logic [           slot_num_lp*2-1:0] rresp ; \
  logic [             slot_num_lp-1:0] rlast ; \
  logic [             slot_num_lp-1:0] rvalid; \
} miso_struct_name

`define bsg_axi4_mosi_bus_width(slot_num_lp, id_width_p, addr_width_p, data_width_p) \
( slot_num_lp * (2*id_width_p + 2*addr_width_p + 2*8 + 4*3 + 2*2 + 6*4 + 8 + data_width_p + data_width_p/8))

`define bsg_axi4_miso_bus_width(slot_num_lp, id_width_p, addr_width_p, data_width_p) \
(slot_num_lp * (6 + 2*id_width_p + 2*2 + data_width_p))


`endif
