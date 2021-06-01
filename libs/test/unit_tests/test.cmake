#
# Test Target Generation Helpers
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

# Creates a new test target of a given name, adds given sources to the new
# tester target (`_test` suffix), and links mock libraries to the target under
# test (`_mocked` suffix) which is created based on the given target
# (`target_name`).
#
# `target_name`     - Name prefix of the new targets.
# `SOURCES`         - List of the test sources.
# `MOCKS`           - List of the mock libraries to be linked (optional).
function(add_test_target target_name)

    set(multiValueArgs SOURCES MOCKS)
    cmake_parse_arguments(
        ADD_TEST_TARGET
        "" # no options
        "" # no one_value_keywords
        "${multiValueArgs}"
        ${ARGN})

    add_mocked_library(${target_name} ${ADD_TEST_TARGET_MOCKS})

    set_target_properties("${target_name}_mocked"
        PROPERTIES
            COMPILE_FLAGS "--coverage"
            LINK_FLAGS    "--coverage")

    add_executable("${target_name}_test"
        ${ADD_TEST_TARGET_SOURCES}
    )

    target_link_libraries("${target_name}_test"
        PRIVATE
        test_main
        "${target_name}_mocked"
    )

    find_package(GTest REQUIRED)
    gtest_discover_tests("${target_name}_test" AUTO)
endfunction()

# Creates a new target with a `_mocked` suffix which links given mock libraries
# instead of the original ones from the source target.
#
# If given target depends on the other libraries (as in the figure below)...
#
#                        -----    -----
#                       | foo |  | bar |
#                        -----    -----
#                           ^      ^
#                           |      |
#                        --------------
#                        | src_target |
#                        --------------
#
# ...the result of calling this function will be a new target with the given
# `MOCKS` linked instead but all other properties kept as is (especially
# sources).
#
#                  -----------      -----------
#                 | foo_mocks |    | bar_mocks |
#                  -----------      -----------
#                         ^          ^
#                         |          |
#                     -------------------
#                    | src_target_mocked |
#                     -------------------
#
# Note that this function can handle cmake's interface library targets as well
# but will generate a mocked non-interface library target.
#
# `src_target`  - Name of the target to be linked with mocks.
# `ARGN`        - List of the mock libraries to be linked (optional).
function(add_mocked_library src_target)
    get_target_property(target_type ${src_target} TYPE)
    if (target_type STREQUAL "INTERFACE_LIBRARY")
        get_target_property(sourceFiles ${src_target} INTERFACE_SOURCES)
        get_target_property(
            includeDirs ${src_target} INTERFACE_INCLUDE_DIRECTORIES)
        get_target_property(
            compileDefinitions ${src_target} INTERFACE_COMPILE_DEFINITIONS)
        get_target_property(
            compileOptions ${src_target} INTERFACE_COMPILE_OPTIONS)
    else ()
        get_target_property(sourceFiles ${src_target} SOURCES)
        get_target_property(includeDirs ${src_target} INCLUDE_DIRECTORIES)
        get_target_property(
            compileDefinitions ${src_target} COMPILE_DEFINITIONS)
        get_target_property(compileOptions ${src_target} COMPILE_OPTIONS)
    endif ()

    add_library(${src_target}_mocked
        ${sourceFiles}
    )

    target_include_directories(${src_target}_mocked
        PUBLIC
            ${includeDirs}
    )

    target_link_libraries(${src_target}_mocked
        PUBLIC
            ${ARGN}
    )

    if (compileDefinitions)
        target_compile_definitions(${src_target}_mocked
            PUBLIC
                ${compileDefinitions}
        )
    endif ()

    if (compileOptions)
        target_compile_options(${src_target}_mocked
            PUBLIC
                ${compileOptions}
        )
    endif ()
endfunction()
