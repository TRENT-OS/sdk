#
# RAM Disk driver
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
    OS_COMPONENT_RamDisk_DIR
    "${CMAKE_CURRENT_LIST_DIR}"
    CACHE INTERNAL ""
)


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
function(DeclareCAmkESComponent_RamDisk
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
            ${OS_COMPONENT_RamDisk_DIR}/RamDisk.c
            ${RAMDISK_IMAGE}
        C_FLAGS
            -Wall -Werror
        LIBS
            ${system_config_lib}
            os_core_api
            os_libs
    )

endfunction()
