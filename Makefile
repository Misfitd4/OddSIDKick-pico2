BUILD_DIR := build
PICO_SDK_PATH := /Users/misfit/pico/pico-sdk
PICO_EXTRAS_PATH := /Users/misfit/pico/pico-extras
TOOLCHAIN := $(PICO_SDK_PATH)/cmake/preload/toolchains/pico_arm_cortex_m33_gcc.cmake
UF2 := $(BUILD_DIR)/OddSIDKick-pico2.uf2
PICO_MOUNT := /Volumes/RPI-RP2
PICOTOOL := $(BUILD_DIR)/_deps/picotool/picotool

.PHONY: all configure build clean flash uf2 bootsel reset

all: build

configure:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake .. -G Ninja \
		-DPICO_BOARD=pico2 \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAIN)

build: configure
	cmake --build $(BUILD_DIR) -j 2

uf2: build
	ls -lah $(UF2)

bootsel: build
	@if [ -x "$(PICOTOOL)" ]; then \
		echo "Resetting Pico into BOOTSEL mode..."; \
		"$(PICOTOOL)" reboot -u -f || true; \
	else \
		echo "picotool not found at $(PICOTOOL). Building first should create it."; \
		exit 1; \
	fi

flash: build
	@if [ ! -d "$(PICO_MOUNT)" ]; then \
		$(MAKE) bootsel; \
		echo "Waiting for $(PICO_MOUNT)..."; \
		for i in 1 2 3 4 5 6 7 8 9 10; do \
			if [ -d "$(PICO_MOUNT)" ]; then break; fi; \
			sleep 1; \
		done; \
	fi
	@if [ ! -d "$(PICO_MOUNT)" ]; then \
		echo "Pico did not mount at $(PICO_MOUNT). Hold BOOTSEL manually and run make flash again."; \
		exit 1; \
	fi
	cp $(UF2) $(PICO_MOUNT)/

reset: build
	"$(PICOTOOL)" reboot -f || true

clean:
	rm -rf $(BUILD_DIR)
