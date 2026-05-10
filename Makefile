BUILDROOT_DIR := $(CURDIR)/common/buildroot
OUTPUT_DIR    := $(CURDIR)/output
BR2_EXTERNAL  := $(CURDIR)/common:$(CURDIR)

CONFIG_EXISTS := $(wildcard $(OUTPUT_DIR)/.config)

.PHONY: all

all:
ifeq ($(CONFIG_EXISTS),)
	@echo "No .config found. Load a defconfig first, e.g.:"
	@echo "  make raspberrypi_myproject_defconfig"
	@exit 1
endif
	$(MAKE) -C $(BUILDROOT_DIR) BR2_EXTERNAL=$(BR2_EXTERNAL) O=$(OUTPUT_DIR)

%:
	$(MAKE) -C $(BUILDROOT_DIR) BR2_EXTERNAL=$(BR2_EXTERNAL) O=$(OUTPUT_DIR) $@
