#
# Analysis Target
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

if (BUILD_ANALYSIS)
    set(CMAKE_C_STANDARD 11)

    project(analysis C)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    add_library(${PROJECT_NAME} SHARED)

    target_link_libraries(${PROJECT_NAME}
        lib_compiler
        lib_debug
        lib_host
        lib_io
        lib_logs
        lib_macros
        lib_mem
        lib_osal
        lib_server
        lib_utils

        ext_mocks
    )

    target_include_directories("${PROJECT_NAME}"
        PUBLIC
        "include"
    )

    target_compile_definitions("${PROJECT_NAME}"
        PUBLIC
        -DMEMORY_CONFIG_H_FILE=system_config.h
        -DDEBUG_CONFIG_H_FILE=system_config.h
    )
endif ()
