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
set DESIGN_PATH       [lindex $argv 1]
set VIVADO_PRJ_DIR    [lindex $argv 2]
set FPGA_PART         [lindex $argv 3]
set DEBUG             [lindex $argv 4]

# source file index
set LVINCLUDES        [lindex $argv 5]
set LVHEADERS         [lindex $argv 6]
set LVSOURCES         [lindex $argv 7]

# source files
set HDLSOURCE         [lrange $argv 8 end]
set VINCLUDES         [lrange $HDLSOURCE 0 [expr {$LVINCLUDES-1}]]
set VHEADERS          [lrange $HDLSOURCE $LVINCLUDES [expr {$LVINCLUDES+$LVHEADERS-1}]]
set VSOURCES          [lrange $HDLSOURCE [expr {$LVINCLUDES+$LVHEADERS}] end]

create_project -force ${DESIGN_NAME} ${VIVADO_PRJ_DIR}/${DESIGN_NAME} -part ${FPGA_PART}


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
# include directories
#
set_property include_dirs ${VINCLUDES} [get_filesets sources_1]

# verilog header files
#
add_files -fileset sources_1 -norecurse [join "${VHEADERS}"]
foreach vfile ${VHEADERS} {
  if {[string match [file extension ${vfile}] ".vh"]} {
    set_property file_type "Verilog Header" [get_files ${vfile}]
  }
  if {[string match [file extension ${vfile}] ".inc"]} {
    set_property file_type "Verilog Header" [get_files ${vfile}]
  }
}
foreach vfile ${VHEADERS} {
  if {[string match [file extension ${vfile}] ".v"]} {
    set_property file_type SystemVerilog [get_files ${vfile}]
  }
}

# system verilog files
#
add_files -fileset sources_1 -norecurse [join "${VSOURCES}"]
foreach vfile ${VSOURCES} {
  if {[string match [file extension ${vfile}] ".v"]} {
    set_property file_type SystemVerilog [get_files ${vfile}]
  }
}
set_property top ${DESIGN_NAME}_top [get_filesets sources_1]

source ${DESIGN_PATH}/${DESIGN_NAME}/patch.tcl

exit

