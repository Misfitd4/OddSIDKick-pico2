BUILD_DIR := build
PICO_SDK_PATH ?= $(HOME)/pico/pico-sdk
PICO_BOARD ?= pico2

.PHONY: all configure build clean flash uf2

all: build

configure:
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && PICO_SDK_PATH=$(PICO_SDK_PATH) cmake .. -DPICO_BOARD=$(PICO_BOARD) -DCMAKE_BUILD_TYPE=Release

build: configure
	cmake --build $(BUILD_DIR) -j

uf2: build
	@find $(BUILD_DIR) -name "*.uf2" -print

flash: build
	cp $(BUILD_DIR)/OddSIDKick-pico2.uf2 /Volumes/RPI-RP2/

clean:
	rm -rf $(BUILD_DIR)
