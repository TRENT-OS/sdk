#
# ChanMux Storage driver
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
# Declare ChanMux Storage Driver CAmkES Component
#
# Parameters:
#
#   <name>
#     required, component instance name
#
function(ChanMux_Storage_DeclareCAmkESComponent
    name
)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ChanMux_Storage.c
        C_FLAGS
            -Wall -Werror
        LIBS
            os_core_api
            os_libs
            proxy_nvm
    )

endfunction()
