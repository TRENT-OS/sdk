#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)


# we cannot use CMAKE_CURRENT_LIST_DIR in a function or macro, because that
# would give us the dir of the file that is invoking the macro. The work around
# is that we create a global (ie cached and flagged as internal) variable here
# and then use it in the macro below. As a convenient side effect we don't
# require anybody else to provide any helper variables, this CMake file becomes
# fully self-contained and "copy&paste safe".
set(
    OS_COMPONENT_ChanMux_DIR
    "${CMAKE_CURRENT_LIST_DIR}"
    CACHE INTERNAL ""
)


if (SDK_USE_CAMKES)

    # folder contains platform specific defaults
    CAmkESAddCPPInclude("${OS_COMPONENT_ChanMux_DIR}/plat/${KernelPlatform}")

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
            ${OS_COMPONENT_ChanMux_DIR}/ChanMux.c
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
