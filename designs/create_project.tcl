#
###
######
##########
###############
#####################

# =====================================
# Setup the vivado project
# =====================================
set DESIGN_NAME       [lindex $argv 0]
set DESIGN_PRJ_DIR    [lindex $argv 1]
set FPGA_PART         [lindex $argv 2]
set DEBUG             [lindex $argv 3]

# source file index
set LVINCLUDES        [lindex $argv 4]
set LVHEADERS         [lindex $argv 5]
set LVSOURCES         [lindex $argv 6]

# source files
set HDLSOURCE         [lrange $argv 7 end]
set VINCLUDES         [lrange $HDLSOURCE 0 [expr {$LVINCLUDES-1}]]
set VHEADERS          [lrange $HDLSOURCE $LVINCLUDES [expr {$LVINCLUDES+$LVHEADERS-1}]]
set VSOURCES          [lrange $HDLSOURCE [expr {$LVINCLUDES+$LVHEADERS}] end]

create_project -force ${DESIGN_NAME} ${DESIGN_PRJ_DIR} -part ${FPGA_PART}


# =====================================
# Set global filelist
# =====================================
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}

if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -constrset constrs_1
}

if {[string equal [get_filesets -quiet sim_1] ""]} {
    create_fileset -simset sim_1
}


# =====================================
# Add synthesis only files
# =====================================

# ---------------------------------------
# include directories
# ---------------------------------------
set_property include_dirs ${VINCLUDES} [get_filesets sources_1]

# ---------------------------------------
# verilog header files
# ---------------------------------------
add_files -fileset sources_1 -norecurse [join "${VHEADERS}"]
foreach vfile ${VHEADERS} {
  if {[string match [file extension ${vfile}] ".vh"]} {
    set_property file_type "Verilog Header" [get_files ${vfile}]
  }
}
foreach vfile ${VHEADERS} {
  if {[string match [file extension ${vfile}] ".v"]} {
    set_property file_type SystemVerilog [get_files ${vfile}]
  }
}

# ---------------------------------------
# system verilog files
# ---------------------------------------
add_files -fileset sources_1 -norecurse [join "${VSOURCES}"]
foreach vfile ${VSOURCES} {
  if {[string match [file extension ${vfile}] ".v"]} {
    set_property file_type SystemVerilog [get_files ${vfile}]
  }
}
set_property file_type {Verilog Header} [get_files *bsg_defines.v]

# ---------------------------------------
# top design file
# ---------------------------------------
set DESIGN_TOP $env(BSG_QCL_DIR)/designs/${DESIGN_NAME}/${DESIGN_NAME}_top.v

add_files -fileset sources_1 "${DESIGN_TOP}"
set_property file_type SystemVerilog [get_files ${DESIGN_TOP}]
reorder_files -fileset sources_1 -front [get_files ${DESIGN_TOP}]

set_property top ${DESIGN_NAME}_top [get_filesets sim_1]
set_property top ${DESIGN_NAME}_top [current_fileset]

# ---------------------------------------
# project related settings and macros
# ---------------------------------------
source ./${DESIGN_NAME}/${DESIGN_NAME}.tcl



