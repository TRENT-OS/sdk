#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
#
# Declare ChanMux CAmkES Component
#
# Parameters:
#
#   <name>
#       component instance name
#
#   <config_file>
#       C file with ChanMux configuration
#
#   <system_config_lib>
#       system config library
#
function(ChanMux_DeclareCAmkESComponent
    name
    config_file
    system_config_lib
)
    set(PLATFORM_DIR "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/plat/${PLATFORM}")
    if (EXISTS "${PLATFORM_DIR}" AND IS_DIRECTORY "${PLATFORM_DIR}")
        CAmkESAddCPPInclude(${PLATFORM_DIR})
    else()
        message(
            FATAL_ERROR
            "Directory '${PLATFORM_DIR}' "
            "for the platform specific parameters is missing!")
    endif()

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ChanMux.c
            ${config_file}
        C_FLAGS
            -Wall
            -Werror
        LIBS
            ${system_config_lib}
            os_core_api
            os_libs
            chanmux_server
    )

endfunction()


#-------------------------------------------------------------------------------
# declare components for ChanMux and UARTs
function(ChanMux_UART_DeclareCAmkESComponents
    name
    config_file
    system_config_lib
)
    DeclareCAmkESComponents_for_UARTs()

    ChanMux_DeclareCAmkESComponent(
        ${name}
        ${config_file}
        ${system_config_lib}
    )
endfunction()
