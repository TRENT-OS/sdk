#
# Prepare target for unit tests.
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


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
