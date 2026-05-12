#!/usr/bin/env bash
set -euo pipefail

cat > CMakeLists.txt <<'CMAKE'
cmake_minimum_required(VERSION 3.13)

set(PICO_BOARD pico2 CACHE STRING "Pico board type")

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(OddSIDKick_pico2 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

file(GLOB SOURCES
    Source/*.c
    Source/*.cpp
)

add_executable(OddSIDKick-pico2
    ${SOURCES}
)

target_include_directories(OddSIDKick-pico2 PRIVATE
    Source
)

target_compile_definitions(OddSIDKick-pico2 PRIVATE
    SKPICO_2350=1
    USE_DAC=1
    ODDSID_SERIAL_INPUT=1
)

target_link_libraries(OddSIDKick-pico2
    pico_stdlib
    pico_multicore
    hardware_pwm
    hardware_flash
    hardware_adc
    hardware_resets
    hardware_watchdog
    hardware_clocks
    hardware_pio
    hardware_uart
    pico_audio_i2s
)

pico_enable_stdio_usb(OddSIDKick-pico2 0)
pico_enable_stdio_uart(OddSIDKick-pico2 0)

pico_add_extra_outputs(OddSIDKick-pico2)
CMAKE

cat > Makefile <<'MAKE'
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
MAKE

echo "Added CMakeLists.txt and Makefile."
