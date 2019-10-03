#include <stdint.h>
#include <stdio.h>
//#include <stdlib.h>
//#include <unistd.h>
//#include <byteswap.h>
//#include <string.h>
//#include <errno.h>
//#include <signal.h>
#include <fcntl.h>
//#include <ctype.h>
//#include <termios.h>

//#include <sys/types.h>
#include <sys/mman.h>

#define MAP_SIZE 32*(1024UL)

int main() {
	int fd;
	void *map_base, *virt_addr;
	uint32_t read_result, write_val;

  if ((fd = open("/dev/xdma0_user", O_RDWR | O_SYNC)) == -1) return 0;
  printf("character device %s opened fd: 0x%x.\n", "/dev/xdma0_user", fd); 
//  fflush(stdout);

  /* map one page */
  map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (map_base == (void *) -1) return 0;
  printf("Memory mapped at address %p.\n", map_base); 
 // fflush(stdout);

  /* calculate the virtual address to be accessed */
  virt_addr = map_base + 0x2000;

	read_result = *((uint8_t *) virt_addr);
	printf("Read : %x\n", read_result);

}

