cmake_minimum_required(VERSION 3.7.2)

#-------------------------------------------------------------------------------
# SEOS Libs config
#-------------------------------------------------------------------------------

SET(SEOS_LIBS_DIR "${CMAKE_SOURCE_DIR}/projects/libs")

macro(seos_set_config_file seos_cfg_file)

    # if seos_cfg_file is a relative path, we assume it to be relative to the
    # cmake file that uses this macro. Unfortunately, this path is not in any
    # SEOS lib's list of include folders, so we must make it an absolute path.
    # This is easy, We can simply prepend it with CMAKE_CURRENT_LIST_DIR, which
    # holds the path of the cmake file that uses this macro.
    # There is one pitcall, macro parameters are immutable, so we need a helper
    # variable here
    set(seos_cfg_file_abs "${seos_cfg_file}")

    if (NOT IS_ABSOLUTE "${seos_cfg_file}")
        set(seos_cfg_file_abs "${CMAKE_CURRENT_LIST_DIR}/${seos_cfg_file}")
    endif()

    if (NOT EXISTS "${seos_cfg_file_abs}")
         message(FATAL_ERROR "SEOS config file not found: ${seos_cfg_file_abs}")
    endif()

    set(DEBUG_CONFIG_H_FILE "${seos_cfg_file_abs}" CACHE STRING "")
    set(MEMORY_CONFIG_H_FILE "${seos_cfg_file_abs}" CACHE STRING "")
    set(LOGS_CONFIG_H_FILE "${seos_cfg_file_abs}" CACHE STRING "")
    set(KEYSTORE_CONFIG_H_FILE "${seos_cfg_file_abs}" ON CACHE STRING "")

endmacro()


macro(seos_use_libs)

    # we maintain a list of SEOS libs here that the sandbox provides. This
    # allows doing a nice sanity check against what the SEOS projects a trying
    # to use. While this makes it quite impossible to sneak new lib in, there
    # is the additional effort when adding new libs. We may remove this list if
    # it turn out to cause more pain than benefit.
    set(SEOS_KNOWN_LIBS
            SEOS_LIBS
            SEOS_LIBS_LOGGER
            SEOS_NETWORK_DRIVER_TAP_PROXY
            SEOS_NW_STACK
            SEOS_CRYPTO
            SEOS_CRYPTO_IMPL_MBEDTLS
            SEOS_KEYSTORE
            SEOS_PARTITION_MANAGER
            SEOS_FILESYSTEM_CORE
            SEOS_FILESYSTEM_FAT
            SEOS_FILESYSTEM_SPIFFS
    )

    foreach(seos_lib ${ARGN})

        if (NOT "${seos_lib}" IN_LIST SEOS_KNOWN_LIBS)
            message(FATAL_ERROR "unknown SEOS library: ${seos_lib}")
        endif()

        set(${seos_lib} ON CACHE BOOL "use ${seos_lib}" FORCE)

    endforeach()

endmacro()


# provide a way how libraries can create a documentation build target. Their
# Doxyfile use DOXYGEN_OUTPUT_DIR env variable. The macro has two string
# parameters that accept shell script snippets that will run a pre and post
# build steps for the doxygen run.
macro(seos_create_doxygen_target doc_target_name pre_action post_action)

    find_package(Doxygen)

    if (DOXYGEN_FOUND AND DOXYGEN_DOT_FOUND)

        set(DOXYGEN_CFG "${CMAKE_CURRENT_LIST_DIR}/Doxyfile")
        if (NOT EXISTS ${DOXYGEN_CFG})
            message(FATAL_ERROR "missing ${DOXYGEN_CFG}")
        endif()

        set(DOXYGEN_SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/tmp-doxygen.sh")
        # this will overwrite any existing file
        file(WRITE ${DOXYGEN_SCRIPT}
            "#!/bin/bash -ue\n"
            "echo \"running doxygen pre action ...\"\n"
            "(\n${pre_action}\n)\n"
            "echo \"running doxygen ...\"\n"
            "export DOXYGEN_OUTPUT_DIR=${CMAKE_CURRENT_BINARY_DIR}\n"
            "${DOXYGEN_EXECUTABLE} ${DOXYGEN_CFG}\n"
            "echo \"running doxygen post action ...\"\n"
            "(\n${post_action}\n)\n"
            "echo \"finished with doxygen helper script\"\n"
        )

        add_custom_target( ${doc_target_name}
            COMMAND chmod +x ${DOXYGEN_SCRIPT}
            COMMAND ${DOXYGEN_SCRIPT}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMENT "Generating Doxygen API documentation for: ${doc_target_name}"
            VERBATIM )

    else()

        message("Doxygen and dot needs to be installed to generate the doxygen documentation")

    endif()

endmacro()


#-------------------------------------------------------------------------------
# seL4 generic build system
#-------------------------------------------------------------------------------

if (SEOS_SANDBOX_DOC)

    seos_use_libs(
        SEOS_LIBS
        SEOS_CRYPTO
        SEOS_KEYSTORE
        SEOS_FILESYSTEM_SPIFFS
        SEOS_NW_STACK
        SEOS_PARTITION_MANAGER
        SEOS_FILESYSTEM_CORE
        SEOS_FILESYSTEM_FAT
    )

    add_subdirectory(${SEOS_LIBS_DIR})

    add_custom_target( seos_sandbox_doc )

    add_dependencies( seos_sandbox_doc
        seos_core_api_doc
        seos_libs_doc
        seos_crypto_doc
        seos_keystore_doc
        seos_filesystem_spiffs_doc
        seos_nw_lib_doc
        seos_filesystem_core_doc
        seos_filesystem_fat_doc
        seos_partition_manager_doc
    )

else()

    # we can't include tools/seL4/cmake-tool/default-CMakeLists.txt here (which
    # includes all.cmake from the same folder, that does the actual job), but
    # have to do the steps manually and inject the caller's project in between.
    include("tools/seL4/cmake-tool/settings.cmake")
    include("tools/seL4/cmake-tool/base.cmake")
    include("tools/seL4/cmake-tool/projects.cmake")

    # inject the caller's project. It must be done before configuration.cmake
    # is called, otherwise all default configuration setttigs are missing and
    # the build fails. With BUILD_PROJECT the caller tells us, where it is. It
    # can be a location outside of the seL4/CAmkES folder, thus we have to set
    # the output folder explicitly. There is "projects/" already for the
    # seL4/CAmkES stuff, so we can add the caller's project there nicely.
    if (NOT BUILD_PROJECT)
        message(FATAL_ERROR "missing BUILD_PROJECT")
    endif()

    if (NOT EXISTS "${BUILD_PROJECT}")
        message(FATAL_ERROR "project not found: ${BUILD_PROJECT}")
    endif()

    get_filename_component(BUILD_PROJECT_NAME "${BUILD_PROJECT}" NAME)
    get_filename_component(BUILD_PROJECT_BASE "${BUILD_PROJECT}" DIRECTORY)

    add_subdirectory(${BUILD_PROJECT_BASE} projects/${BUILD_PROJECT_NAME})

    include("tools/seL4/cmake-tool/configuration.cmake")

endif()
