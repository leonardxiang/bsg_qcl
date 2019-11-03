F1_LIB_DIR = $(BSG_F1_DIR)/libraries
XDMA_DRIVER_DIR = $(BSG_QCL_DIR)/drivers/xdma
DESIGN_RUNTIME_DIR = $(BSG_QCL_DIR)/runtime/$(DESIGN_NAME)

.PHONY: install_driver uninstall_driver \
				patch_f1_lib install_f1_runtime uninstall_f1_runtime \

install_driver:
	$(MAKE) -C $(XDMA_DRIVER_DIR) install

uninstall_driver:
	$(MAKE) -C $(XDMA_DRIVER_DIR) uninstall

patch_f1_lib: $(DESIGN_RUNTIME_DIR)/bsg_manycore_cpp.patch
$(DESIGN_RUNTIME_DIR)/bsg_manycore_cpp.patch:
	$(shell diff -u $(BSG_F1_DIR)/libraries/bsg_manycore.cpp $(DESIGN_RUNTIME_DIR)/bsg_manycore.cpp > $@)
# 	@echo "patch runtime library sources===>"
# 	$(shell patch -u $(BSG_F1_DIR)/libraries/bsg_manycore.cpp -p0 < $^)
	cp $(DESIGN_RUNTIME_DIR)/bsg_manycore.cpp $(BSG_F1_DIR)/libraries/bsg_manycore.cpp

install_f1_runtime: patch_f1_lib
	@echo "install the f1 bladerunner libraries===>"
	$(MAKE) -C $(F1_LIB_DIR) install

uninstall_f1_runtime: uninstall_driver
	@echo "<===unpatch runtime library sources"
	rm -rf $(BSG_F1_DIR)/bsg_manycore_cpp.patch
	$(shell cd $(BSG_F1_DIR)/libraries && rm -rf bsg_manycore.cpp* && git checkout bsg_manycore.cpp)
	rm -rf $(DESIGN_RUNTIME_DIR)/bsg_manycore_cpp.patch
	@echo "<===uninstall the f1 bladerunner libraries"
	$(MAKE) -C $(F1_LIB_DIR) uninstall


# targets below are exposed to outside

software: install_driver install_f1_runtime

remove_sw: uninstall_driver uninstall_f1_runtime
