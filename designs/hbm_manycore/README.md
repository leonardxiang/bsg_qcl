# Hardware Configuration

- `hdl/bsg_bladerunner_pkg.v` defines the hardware parameters used on FPGA
- With current cache version, we use `axi_data_width_p` = 32\*`block_size_in_words_p`/`axi_burst_len_p`
- We also instantialize several Xilinx IPs from the ip generator. Their parameters can be changed in `f1_manycore.tcl`

# Regression Test
See [bsg_f1/regression/README.md](https://github.com/bespoke-silicon-group/bsg_f1/tree/master/regression)