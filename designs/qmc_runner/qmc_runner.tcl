# =====================================
# Add vivado ip source files
# =====================================
set XILINX_IP_DIR $env(XILINX_VIVADO_DIR)/data/ip/xilinx
set IP_WRAPPER_DIR $env(BSG_QCL_DIR)/hdl/xilinx_ip

# =====================================
# generate ips
# =====================================
set PRJ_IP_DIR ${DESIGN_PRJ_DIR}/${DESIGN_NAME}.srcs/sources_1/ip


# =====================================
# add constraints
# =====================================
set CONSTRAINT_DIR ./${DESIGN_NAME}/constraints
