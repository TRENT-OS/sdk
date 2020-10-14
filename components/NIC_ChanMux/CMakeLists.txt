#
# NIC ChanMux driver
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
    OS_COMPONENT_NIC_ChanMux_DIR
    "${CMAKE_CURRENT_LIST_DIR}"
    CACHE INTERNAL ""
)


#-------------------------------------------------------------------------------
#
# Declare ChanMux NIC Driver CAmkES Component
#
# Parameters:
#
#   <name>
#     component instance name
#
#   <channel_ctrl>
#     ChanMux control channel ID
#
#   <channel_data>
#     ChanMux data channel ID
#

function(DeclareCAmkESComponent_NIC_ChanMux
    name
    channel_ctrl
    channel_data
)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${OS_COMPONENT_NIC_ChanMux_DIR}/driver.c
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

endfunction()
