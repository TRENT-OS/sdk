#
# RAM Disk driver
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
#
# Declare RAM Disk CAmkES Component
#
# Parameters:
#
#   <name>
#       component instance name
#
#   <system_config_lib>
#       system config library with definition for RAMDISK_SIZE_BYTES
#
function(RamDisk_DeclareCAmkESComponent
    name
    system_config_lib
)

    # Let pass an IMAGE parameter, which contains an RLE-encoded buffer with
    # a RamDisk image; this parameter is optional though
    cmake_parse_arguments(
        PARSE_ARGV
        2
        RAMDISK
        ""
        "IMAGE"
        ""
    )

    if(DEFINED RAMDISK_IMAGE)
        message(STATUS "Building RamDisk with image ${RAMDISK_IMAGE}")
    endif(DEFINED RAMDISK_IMAGE)

    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/RamDisk.c
            ${RAMDISK_IMAGE}
        C_FLAGS
            -Wall -Werror
        LIBS
            ${system_config_lib}
            os_core_api
            os_libs
    )

endfunction()
