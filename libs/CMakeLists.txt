#
# Prepare targets for analysis and unit tests.
#
# Copyright (C) 2021-2024, HENSOLDT Cyber GmbH
# 
# SPDX-License-Identifier: GPL-2.0-or-later
#
# For commercial licensing, contact: info.cyber@hensoldt.net
#


cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
# ANALYSIS
#-------------------------------------------------------------------------------
option(BUILD_ANALYSIS "" OFF)
if (BUILD_ANALYSIS)

    project(test)

    # Analysis project
    set(ANALYSIS_MAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/test/analysis")
    add_subdirectory(${ANALYSIS_MAIN_DIR})

    # Libs to be analyzed
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

    # External mocks
    add_subdirectory(test/ext_mocks)
endif ()


#-------------------------------------------------------------------------------
# TESTING
#-------------------------------------------------------------------------------
option(BUILD_TESTING "" OFF)
if (BUILD_TESTING)

    project(test)

    # Unit test project
    set(TEST_MAIN_DIR "${CMAKE_CURRENT_LIST_DIR}/test/unit_tests")
    add_subdirectory(${TEST_MAIN_DIR})

    # CTest
    include(CTest)

    # Libs to be unit tested
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

    # External mocks
    add_subdirectory(test/ext_mocks)
endif ()
