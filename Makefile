DESINS_TARGETS = f1_manycore
DESIGN_NAME ?= f1_manycore

.PHONY: help create_prj open_prj clean bleach bleach_all %.bleach

create_prj:
	$(MAKE) -C designs create DESIGN_NAME=$(DESIGN_NAME)

open_prj:
	$(MAKE) -C designs open DESIGN_NAME=$(DESIGN_NAME)

clean:
	$(MAKE) -C designs clean DESIGN_NAME=$(DESIGN_NAME)

bleach_all: $(addsuffix .bleach,$(DESINS_TARGETS))
%.bleach:
	$(MAKE) -C designs bleach DESIGN_NAME=$(basename $@)
