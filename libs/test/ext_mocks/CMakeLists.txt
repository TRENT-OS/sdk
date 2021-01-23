#
# External Mocks
#
# Temporary target for all mocks outside of the libs.
#
# Please note that this project must be updated if external modules' API has
# been changed.
#
# TODO: To be removed once it is clear on how to solve the libs dependencies on
#       the external modules.
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

if (BUILD_TESTING)
    project(ext_mocks CXX)

    add_library(${PROJECT_NAME} INTERFACE)

    target_include_directories(${PROJECT_NAME}
        INTERFACE
            "include"
    )
endif ()
