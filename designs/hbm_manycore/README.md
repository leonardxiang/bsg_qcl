# Dependency:
bsg_bladerunner v3.6.0
+ bsg_replicant/local_fpga_emulation 175e6c7

# Hardware Configuration
- set up env

  `export QCL_DESIGN_NAME=hbm_manycore`

- `hdl/bsg_bladerunner_pkg.v` defines the hardware parameters used on FPGA
- With current cache version, we use `axi_data_width_p` = 32\*`block_size_in_words_p`/`axi_burst_len_p`
- We also instantialize several Xilinx IPs from the ip generator. Their parameters can be changed in `f1_manycore.tcl`

# Regression Test
## install the xdma driver and hb_manycore runtime
- `cd $QCL_REPO_DIR`
- `sudo -E make install_sw`

## run regression tests on bsg_replicant repo
See [bsg_f1/regression/README.md](https://github.com/bespoke-silicon-group/bsg_replicant/tree/master/regression)
