cmake_minimum_required(VERSION 3.13)

set(PICO_BOARD pico2 CACHE STRING "Pico board type")
set(PICO_SDK_PATH "/Users/misfit/pico/pico-sdk" CACHE PATH "Path to Pico SDK")
set(PICO_EXTRAS_PATH "/Users/misfit/pico/pico-extras" CACHE PATH "Path to Pico Extras")

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)
include(${PICO_EXTRAS_PATH}/external/pico_extras_import.cmake)

project(OddSIDKick_pico2 C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

set(SOURCES
    Source/SKpico.c
    Source/exodecr.c
    Source/reSIDWrapper.cc
    Source/oddsid_stubs.c
    Source/fmopl.c

    Source/reSID16/envelope.cc
    Source/reSID16/extfilt.cc
    Source/reSID16/filter.cc
    Source/reSID16/pot.cc
    Source/reSID16/sid.cc
    Source/reSID16/voice.cc
    Source/reSID16/wave.cc
    Source/reSID16/version.cc


)

add_executable(OddSIDKick-pico2
    ${SOURCES}
)

target_include_directories(OddSIDKick-pico2 PRIVATE
    Source
    Source/reSID16
)

target_compile_definitions(OddSIDKick-pico2 PRIVATE
    SKPICO_2350=1
    VERSION="reSID16-OddSIDKick"
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
