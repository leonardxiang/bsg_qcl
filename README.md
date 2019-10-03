# BSG QCL

This repo is for porting the bsg_bladerunner project on local FPGA board.

## Folders

- `designs`: Hardware designs to be ported on FPGA
- `drivers`: Linux or Windows (3rd-party) drivers for the hardware designs above
- `hdl`: Verilog source files that are commonly used among designs

## Dependencies

   1. Vivado 2018.2
   2. A clone of [bsg_bladerunner](https://github.com/bespoke-silicon-group/bsg_bladerunner) and proper setup
   3. Reference Repositories:
    - [BSG Manycore](https://github.com/bespoke-silicon-group/bsg_manycore)
    - [BaseJump STL](https://github.com/bespoke-silicon-group/basejump_stl)
    - [AWS FPGA](https://github.com/aws/aws-fpga)

## Environment Variables(set by user)

  - `XILINX_VIVADO_DIR`: Vivado install directory, used to deduce the Xilinx IP source files
  - `VIVADO_PRJ_DIR`: Vivado project creation directroy
  - `BSG_QCL`: This repo's path 
  - `BSG_BLADERUNNER_DIR`: Path of repo bsg_bladerunner, for reusing the F1 bladerunner infrastructure

## How to Use

User should specify the `DESIGN_NAME` variable for certain design targets

#### Create a Design Project
   
  `$ make create_prj DESIGN_NAME=f1_manycore`

#### Open a Existing Project

  `$ make open_prj DESIGN_NAME=f1_manycore`

  - See `make help` for more...

## Debug a Project

   1. Open a design in Vivado **project mode**; type tcl command *start_gui*
   2. Run synthesis, you can put attribute `(* mark_debug = "true" *)` before the signal declaration in the verilog source file
   3. Click *Set Up Debug* under *Open Synthesized Design* menu
   4. Choose the signals that you want to inspect, Update the xdc file automatically
   5. *Run implementation* and *Generate Bitstream*

   reference https://www.xilinx.com/video/hardware/logic-debug-in-vivado.html