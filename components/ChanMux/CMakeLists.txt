#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)


if (SDK_USE_CAMKES)

    # folder contains platform specific defaults
    CAmkESAddCPPInclude("${CMAKE_CURRENT_LIST_DIR}/plat/${KernelPlatform}")

endif()


# we cannot use CMAKE_CURRENT_LIST_DIR in a macro, because that would give us
# the dir of the file that is invoking the macro. The work around is that we
# create a global variable here and then use this in the macro below. Note that
# we do this, so we don't require anybody else to provide any helper variables,
# this CMake file becomes fully self-contained and is "copy&paste safe".
set(COMPONENT_CHANMUX_DIR ${CMAKE_CURRENT_LIST_DIR})


#-------------------------------------------------------------------------------
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
