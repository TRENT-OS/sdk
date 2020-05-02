#
# ChanMux
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)


# we cannot use CMAKE_CURRENT_LIST_DIR in a macro, because that would give us
# the dir of the file that is invoking the macro. The work around is that we
# create a global variable here and then use this in the macro below. Note that
# we do this, so we don't require anybody else to provide any helper variables,
# this CMake file becomes fully self-contained and is "copy&paste safe".
set(COMPONENT_CHANMUX_DIR ${CMAKE_CURRENT_LIST_DIR})


macro(DeclareCAmkESComponent_ChanMux name config_file system_config_lib)

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
            seos_core_api
            seos_libs
            chanmux_server
    )

endmacro()
