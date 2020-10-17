#
# SPI-Flash
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
set(OS_COMPONENT_Storage_Flash_SPI_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")


CAmkESAddImportPath("${OS_COMPONENT_Storage_Flash_SPI_DIR}")


function(DeclareCAmkESComponent_Storage_Flash_SPI name)

    # Let caller provide libs, we need at least a TimeServer client lib
    cmake_parse_arguments(
        PARSE_ARGV
        1
        STORAGE_FLASH_SPI
        ""
        ""
        "LIBS"
    )


    DeclareCAmkESComponent(
        ${name}
        SOURCES
            ${OS_COMPONENT_Storage_Flash_SPI_DIR}/Storage_Flash_SPI.c
        C_FLAGS
            -Wall
            -Werror
        LIBS
            os_core_api
            os_libs
            ${STORAGE_FLASH_SPI_LIBS}
    )

endfunction()

