
.PHONY: driver rules load install uninstall

uninstall:
	rmmod -s xdma | true
	rm -f /etc/udev/rules.d/60-xdma.rules
	rm -f /etc/udev/rules.d/xdma-udev-command.sh

install: driver rules load
	modinfo driver/xdma.ko

driver:
	$(MAKE) -C $@

rules:
	cp etc/udev/rules.d/* /etc/udev/rules.d/

load:
	cd tests; \
	./load_driver.sh
