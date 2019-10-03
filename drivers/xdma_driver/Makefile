HB_MC_F1_DRIVER_DIR = $(BSG_F1_DIR)/cl_manycore/libraries

install_bladerunner_lib: install_xdma_driver
	@echo "install the f1 bladerunner libraries=>"
	$(MAKE) -C $(HB_MC_F1_DRIVER_DIR) install BSG_TARGET_F1=0

uninstall_bladerunner_lib:
	@echo "<=uninstall the bsg_manycore_dirver"
	$(MAKE) -C $(HB_MC_F1_DRIVER_DIR) uninstall

uninstall_xdma_driver:
	rmmod -s xdma
	rm -f /etc/udev/rules.d/60-xdma.rules
	rm -f /etc/udev/rules.d/xdma-udev-command.sh

install_xdma_driver: driver rules load
	modinfo driver/xdma.ko

driver:
	$(MAKE) -C $@

rules:
	cp etc/udev/rules.d/* /etc/udev/rules.d/

load:
	cd tests; \
	./load_driver.sh

.PHONY: driver rules load install_xdma_driver install uninstall
