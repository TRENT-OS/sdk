#
# External Mocks
#
# Target for all mocks outside of the libs.
#
# Please note that the mocks have to be updated if the mocked modules change.
#
# TODO: To be removed once it is clear on how to solve the libs dependencies on
#       the external modules.
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)


#-------------------------------------------------------------------------------
# ANALYSIS
#-------------------------------------------------------------------------------
if (BUILD_ANALYSIS)
    project(ext_mocks C)

    add_library(${PROJECT_NAME} INTERFACE)

    target_include_directories(${PROJECT_NAME}
        INTERFACE
            "include"
    )

    # NOTE: In additon to the external mocks the library os_core_api has to be
    # defined (even if empty) to link the shared library for analysis.

    project(os_core_api C)

    add_library(${PROJECT_NAME} INTERFACE)
endif ()


#-------------------------------------------------------------------------------
# TESTING
#-------------------------------------------------------------------------------
if (BUILD_TESTING)
    project(ext_mocks CXX)

    add_library(${PROJECT_NAME} INTERFACE)

    target_include_directories(${PROJECT_NAME}
        INTERFACE
            "include"
    )
endif ()
