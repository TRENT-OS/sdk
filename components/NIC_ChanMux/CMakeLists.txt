#
# NIC ChanMux Driver
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)


# we cannot use CMAKE_CURRENT_LIST_DIR in a macro, because that would give us
# the dir of the file that is invoking the macro. The work around is that we
# create a global variable here and then use this in the macro below. Note that
# we do this, so we don't require anybody else to provide any helper variables,
# this CMake file becomes fully self-contained and is "copy&paste safe".
set(COMPONENT_NIC_CHANMUX_DIR ${CMAKE_CURRENT_LIST_DIR})


macro(DeclareCAmkESComponent_NIC_ChanMux name channel_ctrl channel_data)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${COMPONENT_NIC_CHANMUX_DIR}/driver.c
        C_FLAGS
            -DCFG_CHANMUX_CHANNEL_CRTL=${channel_ctrl}
            -DCFG_CHANMUX_CHANNEL_DATA=${channel_data}
            -Wall
            -Werror
        LIBS
            os_core_api
            os_libs
            chanmux_nic_driver
    )

endmacro()
