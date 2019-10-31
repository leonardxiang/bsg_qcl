#ifndef BSG_MANYCORE_LOCAL_FPGA_H
#define BSG_MANYCORE_LOCAL_FPGA_H

#define FPGA_TARGET_LOCAL
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <unistd.h>
#include <limits.h>
const size_t MAP_SIZE=32768UL;
const char* device_name = "/dev/xdma0_user";

#endif