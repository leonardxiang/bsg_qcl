# BSG QCL

This repo is for porting the bsg_bladerunner project on local FPGA board.

## Folders

This repository contains the following folders: 

- `designs`: Hardware designs to be ported on FPGA
- `drivers`: Linux or Windows (3rd-party) drivers for the hardware designs above
- `hdl`: Verilog source files that are commonly used among designs

## Dependencies

   1. Vivado 2018.2
   2. A clone of [bsg_bladerunner](https://github.com/bespoke-silicon-group/bsg_bladerunner) and proper setup
   3. Reference Repositories:
    - [bsg_manycore](https://github.com/bespoke-silicon-group/bsg_manycore)
    - [basejump_stl](https://github.com/bespoke-silicon-group/basejump_stl)
    - [aws-fpga](https://github.com/aws/aws-fpga)

## Environment Variables(set by user)

  - `XILINX_VIVADO_DIR`: Vivado install directory, used to deduce the Xilinx IP source files
  - `VIVADO_PRJ_DIR`: Vivado project creation directroy
  - `BSG_QCL_DIR`: Path of this repo
  - `BSG_BLADERUNNER_DIR`: Path of repo bsg_bladerunner, for reusing the F1 bladerunner infrastructure

## How to Use

User should define the `DESIGN_NAME` variable to specify the design target

#### Create a Design Project
   
  `$ make create_prj DESIGN_NAME=f1_manycore`

#### Open a Existing Project

  `$ make open_prj DESIGN_NAME=f1_manycore`
  
  See `make help` for more info...

## Debug a Project

   1. Open a design in Vivado **project mode**; type tcl command *start_gui*

   2. Run synthesis

      Note that you can put attribute `(* mark_debug = "true" *)` before the signal of interest in the verilog source file, so as to put the debug probe automatically after synthesis

   3. Click *Set Up Debug* under *Open Synthesized Design* menu

   4. Choose the signals that you want to inspect, then update the xdc file

   5. *Run implementation* and *Generate Bitstream*

    reference: https://www.xilinx.com/video/hardware/logic-debug-in-vivado.html