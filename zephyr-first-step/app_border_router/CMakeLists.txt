# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)
list(APPEND ZEPHYR_EXTRA_MODULES /home/karilla/Cours/TB/zephyr-nanostack)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
target_link_libraries(app PUBLIC zephyr_library_nanostack)
project(app_border_router)

target_sources(app PRIVATE src/main.c)
