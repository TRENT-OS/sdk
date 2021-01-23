#
# The Libraries' test targets
#
# Adds all subdirectories that are containing test targets.
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

option(BUILD_TESTING "" OFF)
if (BUILD_TESTING)
    set(CMAKE_CXX_STANDARD 20)
    set(TEST_MAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/test")

    project(unit_tests CXX)

    include(CTest)
    add_subdirectory(${TEST_MAIN_DIR})
    add_subdirectory(lib_compiler)
    add_subdirectory(lib_debug)
    add_subdirectory(lib_host)
    add_subdirectory(lib_io)
    add_subdirectory(lib_logs)
    add_subdirectory(lib_macros)
    add_subdirectory(lib_mem)
    add_subdirectory(lib_osal)
    add_subdirectory(lib_server)
    add_subdirectory(lib_utils)
endif ()
