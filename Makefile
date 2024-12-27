# Menetapkan direktori dan file
PROFILE_DIR := profiles
PROFILE_FILE := $(PROFILE_DIR)/profile-1.yml

# Helper function to parse YAML
parse = $(shell yq $1 $(PROFILE_FILE))

DISK_IMAGE := $(call parse, .disk_image.file)
ISO_FILE := $(call parse, .iso.file)
ISO_URL := $(call parse, .iso.url)
ROM_FILE := $(call parse, .rom.file)
ROM_URL := $(call parse, .rom.url)
SCRIPT := scripts/profile-1.sh


.PHONY: help test clean
.PRECIOUS: $(ISO_FILE) $(DISK_IMAGE) $(ROM_FILE)

# Help target
help:
	@echo "Available targets:"
	@echo "  test    - Test and display configuration info"
	@echo "  clean   - Remove generated files"
	@echo "  $(SCRIPT) - Generate QEMU script"

$(DISK_IMAGE): $(PROFILE_FILE)
	@echo "Creating disk image"
	@mkdir -p $$(dirname $(DISK_IMAGE))
	@qemu-img create -f vdi $(DISK_IMAGE) $(call parse, .disk_image.size)

$(ISO_FILE): $(PROFILE_FILE)
	@echo "Checking for ISO file: $(ISO_FILE)"
	@if [ ! -f $(ISO_FILE) ]; then \
		mkdir -p $$(dirname $(ISO_FILE)); \
		echo "ISO file not found, trying to download from URL..."; \
		curl -# -L -o $(ISO_FILE) $(ISO_URL); \
	fi

$(ROM_FILE): $(PROFILE_FILE)
	@ROM_CONFIG=$$(yq .rom $(PROFILE_FILE)); \
	if [ "$$ROM_CONFIG" = "null" ]; then \
		echo "ROM not specified, using default"; \
		exit 0; \
	elif [ -f "$(ROM_FILE)" ]; then \
		echo "ROM file found at: $(ROM_FILE)"; \
	elif [ "$(ROM_URL)" != "null" ]; then \
		echo "Downloading ROM from URL..."; \
		mkdir -p $$(dirname "$(ROM_FILE)"); \
		curl -# -L "$(ROM_URL)" -o "$(ROM_FILE)"; \
	else \
		echo "Error: Neither ROM file nor URL specified"; \
		exit 1; \
	fi

$(SCRIPT): $(PROFILE_FILE) $(ROM_FILE) $(DISK_IMAGE) $(ISO_FILE)
	@mkdir -p $$(dirname $(SCRIPT))
	@echo "#!/bin/bash" > $(SCRIPT)
	@echo "qemu-system-$(call parse, .architecture) \\" >> $(SCRIPT)
	@echo "  -machine $(call parse, .machine) \\" >> $(SCRIPT)
	@echo "  -m $(call parse, .memory) \\" >> $(SCRIPT)
	@echo "  -smp $(call parse, .cpu_cores) \\" >> $(SCRIPT)
	@echo "  -boot order=$(call parse, .boot_order) \\" >> $(SCRIPT)
	@if [ "$(call parse, .rom)" != "null" ]; then \
		echo "  -bios $(ROM_FILE) \\" >> $(SCRIPT); \
	fi
	@echo "  -drive file=$(DISK_IMAGE),format=vdi \\" >> $(SCRIPT)
	@echo "  -cdrom $(ISO_FILE) \\" >> $(SCRIPT)
	@echo "  -display $(call parse, .display) \\" >> $(SCRIPT)
	@if [ "$(call parse, .network.enabled)" = "true" ]; then \
		echo "  -net nic,model=$(call parse, .network.model) \\" >> $(SCRIPT); \
		echo "  -net user \\" >> $(SCRIPT); \
	fi
	@if [ "$(call parse, .audio.enabled)" = "true" ]; then \
		echo "  -audiodev $(call parse, .audio.driver),id=audio0 \\" >> $(SCRIPT); \
		echo "  -device $(call parse, .audio.device),audiodev=audio0 \\" >> $(SCRIPT); \
	fi
	@if [ "$(call parse, .usb.enabled)" = "true" ]; then \
		echo "  -usb \\" >> $(SCRIPT); \
		echo "  -device $(call parse, .usb.device) \\" >> $(SCRIPT); \
	fi
	@chmod +x $(SCRIPT)

# Target untuk menguji dan menampilkan informasi
test: $(SCRIPT)
	@echo "Configuration Info:"
	@echo "----------------"
	@echo "Disk Image: $(DISK_IMAGE)"
	@echo "ISO File: $(ISO_FILE)"
	@echo "ROM File: $(ROM_FILE)"
	@echo "Script: $(SCRIPT)"
	@echo "Architecture: $(call parse, .architecture)"
	@echo "Machine: $(call parse, .machine)"
	@echo "Memory: $(call parse, .memory)"
	@echo "CPU Cores: $(call parse, .cpu.cores)"
	@echo "Boot Order: $(call parse, .boot_order)"
	@echo "Display: $(call parse, .display)"

# Target untuk membersihkan file yang dibuat
clean:
	@echo "Cleaning generated files..."
	@rm -f $(SCRIPT)
	@[ -f $(DISK_IMAGE) ] && rm -f $(DISK_IMAGE) || true
	