#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)


# create a global variable here and then use this in the macro below. Note that
# we do this, so we don't require anybody else to provide any helper variables,
# this CMake file becomes fully self-contained and is "copy&paste safe".
set(COMPONENT_CHANMUX_DIR ${CMAKE_CURRENT_LIST_DIR})


if (SDK_USE_CAMKES)

    # folder contains platform specific defaults
    CAmkESAddCPPInclude("${COMPONENT_CHANMUX_DIR}/plat/${KernelPlatform}")

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
macro(DeclareCAmkESComponent_ChanMux
    name
    config_file
    system_config_lib
)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${COMPONENT_CHANMUX_DIR}/ChanMux.c
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

endmacro()
