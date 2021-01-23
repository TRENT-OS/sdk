#
# The Test Main Target
#
# Links gtest framwork, enables testing and calculates coverage.
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

if (BUILD_TESTING)
    set(CMAKE_CXX_STANDARD 20)

    project(test_main LANGUAGES CXX)

    add_library(${PROJECT_NAME}
        "test_main.cpp")

    find_package(GTest REQUIRED)

    target_link_libraries(${PROJECT_NAME}
        PRIVATE
            GTest::GTest
            GTest::Main
            pthread
            gcov
    )

    add_custom_target(covr
        COMMAND mkdir -p coverage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )

    add_custom_command(TARGET covr
        COMMAND echo "=================== LCOV ===================="

        COMMAND echo "Generating initial zero coverage..."
        COMMAND lcov -c -i --directory ${CMAKE_BINARY_DIR}
                        --output-file init_coverage.info

        COMMAND echo "Generating base coverage..."
        COMMAND lcov -c --directory ${CMAKE_BINARY_DIR}
                        --output-file base_coverage.info

        COMMAND echo "Generating combined coverage..."
        COMMAND lcov -a init_coverage.info -a base_coverage.info
                        -o coverage.info

        COMMAND echo "Generating HTML report..."
        COMMAND genhtml -o html coverage.info

        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/coverage
    )

    #---------------------------------------------------------------------------
    # External Mocks
    #---------------------------------------------------------------------------
    add_subdirectory(ext_mocks)
endif ()
