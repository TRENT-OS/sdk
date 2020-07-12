#
# ChanMux_Storage
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
    OS_COMPONENT_ChanMux_Storage_DIR
    "${CMAKE_CURRENT_LIST_DIR}"
    CACHE INTERNAL ""
)


#-------------------------------------------------------------------------------
# Declare ChanMux Storage Driver CAmkES Component
#
# Parameters:
#
#   <name>
#     required, component instance name
#
function(DeclareCAmkESComponent_ChanMux_Storage
    name
)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${OS_COMPONENT_ChanMux_Storage_DIR}/ChanMux_Storage.c
        C_FLAGS
            -Wall -Werror
        LIBS
            os_core_api
            os_libs
            proxy_nvm
    )

endfunction()
