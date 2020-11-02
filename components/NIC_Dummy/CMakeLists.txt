#
# NIC Dummy driver
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
#
# Declare Dummy NIC CAmkES Component
#
# Parameters:
#
#   <name>
#       component instance name
#
function(NIC_Dummy_DeclareCAmkESComponent
    name
)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/driver.c
        C_FLAGS
            -Wall
            -Werror
        LIBS
            os_core_api
            os_libs
    )

endfunction()
