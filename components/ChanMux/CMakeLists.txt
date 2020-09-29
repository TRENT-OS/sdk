#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


if (SDK_USE_CAMKES)

    # folder contains platform specific defaults
    CAmkESAddCPPInclude("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/plat/${KernelPlatform}")

endif()


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
function(DeclareCAmkESComponent_ChanMux
    name
    config_file
    system_config_lib
)

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
