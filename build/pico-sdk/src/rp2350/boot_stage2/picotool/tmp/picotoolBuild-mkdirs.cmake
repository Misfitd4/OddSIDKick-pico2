# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file LICENSE.rst or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/_deps/picotool-src")
  file(MAKE_DIRECTORY "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/_deps/picotool-src")
endif()
file(MAKE_DIRECTORY
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/_deps/picotool-build"
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/_deps"
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/tmp"
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/src/picotoolBuild-stamp"
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/src"
  "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/src/picotoolBuild-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/src/picotoolBuild-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/misfit/Desktop/dev/OddSIDKick-pico2/build/pico-sdk/src/rp2350/boot_stage2/picotool/src/picotoolBuild-stamp${cfgdir}") # cfgdir has leading slash
endif()
