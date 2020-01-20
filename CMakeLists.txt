cmake_minimum_required(VERSION 3.7.2)

set(SEOS_SANDBOX_DIR "${CMAKE_CURRENT_LIST_DIR}")

#-------------------------------------------------------------------------------
# CAmkES
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# SEOS project can use this macro to get the CAmkES environment
macro(seos_import_camkes)

# ToDo: make me work again

endmacro()


#-------------------------------------------------------------------------------
# SEOS Libs config
#-------------------------------------------------------------------------------

SET(SEOS_LIBS_DIR "${SEOS_SANDBOX_DIR}/projects/libs")

#-------------------------------------------------------------------------------
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


#-------------------------------------------------------------------------------
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
            SEOS_TLS
            SEOS_TLS_IMPL_MBEDTLS
            SEOS_KEYSTORE
            SEOS_PARTITION_MANAGER
            SEOS_FILESYSTEM_CORE
            SEOS_FILESYSTEM_FAT
            SEOS_FILESYSTEM_SPIFFS
            SEOS_FILESYSTEM_SPIFFS_LEGACY
            SEOS_CONFIGURATION
    )

    foreach(seos_lib ${ARGN})

        if (NOT "${seos_lib}" IN_LIST SEOS_KNOWN_LIBS)
            message(FATAL_ERROR "unknown SEOS library: ${seos_lib}")
        endif()

        set(${seos_lib} ON CACHE BOOL "use ${seos_lib}" FORCE)

    endforeach()

endmacro()


#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
macro(seos_sandbox_build_doc)

    seos_use_libs(
        SEOS_LIBS
        SEOS_CRYPTO
        SEOS_TLS
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
        seos_tls_doc
        seos_keystore_doc
        seos_filesystem_spiffs_doc
        seos_nw_lib_doc
        seos_filesystem_core_doc
        seos_filesystem_fat_doc
        seos_partition_manager_doc
    )

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/seos-api-index.html
        "<!doctype html>\n"
        "<html>\n"
        "  <head></head>\n"
        "  <body>\n"
        "    <ul>\n"
        "    <li><a href=\"seos_core_api/index.html\">Core API</a></li>\n"
        "    <li><a href=\"seos_crypto/index.html\">Crypo</a></li>\n"
        "    <li>\n"
        "        <a href=\"seos_filesystem_core/index.html\">Filesystem Core</a>\n"
        "        <ul>\n"
        "        <li><a href=\"seos_filesystem_fat/index.html\">Filesystem FAT</a></li>\n"
        "        <li><a href=\"seos_filesystem_spiffs/index.html\">Filesystem SPIFFS</a></li>\n"
        "        </ul>\n"
        "    </li>\n"
        "    <li><a href=\"seos_keystore/index.html\">Keystore</a></li>\n"
        "    <li><a href=\"seos_libs/index.html\">Libs</a></li>\n"
        "    <li><a href=\"seos_nwstack/index.html\">Network Stack</a></li>\n"
        "    <li><a href=\"seos_partition_manager/index.html\">Partition Manager</a></li>\n"
        "    </ul>\n"
        "  </body>\n"
        "</html>\n"
    )

endmacro()


#-------------------------------------------------------------------------------
macro(seos_sandbox_build seos_project_dir)

    #---------------------------------------------------------------------------
    # SEOS default settings for a seL4 based CAmkES system.
    #---------------------------------------------------------------------------

    set(SEL4_CONFIG_DEFAULT_ADVANCED ON)

    set(RELEASE OFF CACHE BOOL "Performance optimized build")
    set(SIMULATION ON CACHE BOOL "Try and use simulable features")
    set(VERIFICATION OFF CACHE BOOL "Only verification friendly kernel features")

    # we need one scheduling domain only
    set(KernelNumDomains 1 CACHE STRING "" FORCE)

    # default is 12 and thus there are 4096 (= 2^12) slots.
    set(KernelRootCNodeSizeBits 15 CACHE STRING "" FORCE)

    # defaults is 4096, but it too small for more complex systems. What must
    # hold is: CapDLLoaderMaxObjects + Systemcaps < 2^KernelRootCNodeSizeBits
    set(CapDLLoaderMaxObjects 28000 CACHE STRING "" FORCE)

    # enable full debug for capdl-loader-app, e.g. to get information about the
    # required capability slots
    set(LibUtilsDefaultZfLogLevel 0 CACHE STRING "" FORCE)

    #---------------------------------------------------------------------------
    # use the seL4/CAmkES build system
    #---------------------------------------------------------------------------

    # internal helper variable
    set(SEL4_CMAKE_TOOL "${CMAKE_SOURCE_DIR}/tools/seL4/cmake-tool")

    # for CMake to work properly, a project must be defined
    project(camkes C CXX ASM)

    # module search paths
    list(APPEND CMAKE_MODULE_PATH
        ${SEL4_CMAKE_TOOL}/helpers
        ${CMAKE_SOURCE_DIR}/tools/camkes
        ${CMAKE_SOURCE_DIR}/kernel
        ${CMAKE_SOURCE_DIR}/tools/seL4/elfloader-tool
        ${CMAKE_SOURCE_DIR}/projects/camkes/capdl
        # seL4 and CAmkES libs
        ${CMAKE_SOURCE_DIR}/projects/musllibc
        ${CMAKE_SOURCE_DIR}/projects/sel4runtime
        ${CMAKE_SOURCE_DIR}/projects/sel4_util_libs
        ${CMAKE_SOURCE_DIR}/projects/sel4_libs
        ${CMAKE_SOURCE_DIR}/projects/sel4_project_libs
    )

    # CMake interactive build debugging. Seem that set_break() does not work
    # unless the ${SEL4_CMAKE_TOOL}/helpers/cmakerepl is renamed to *.camkes
    include(${SEL4_CMAKE_TOOL}/helpers/debug.cmake)

    # platform settings
    include(${SEL4_CMAKE_TOOL}/helpers/application_settings.cmake)
    correct_platform_strings()
    find_package(seL4 REQUIRED)
    sel4_configure_platform_settings()

    # include lots of helper from tools/seL4/cmake-tool/helpers
    include(${SEL4_CMAKE_TOOL}/common.cmake)

    include(simulation)

    find_package(camkes-tool REQUIRED)
    camkes_tool_setup_camkes_build_environment()

    #---------------------------------------------------------------------------
    # SEOS specific build process
    #---------------------------------------------------------------------------

    CAmkESAddImportPath(${SEOS_LIBS_DIR}/seos_core_api/camkes)
    add_subdirectory("${SEOS_LIBS_DIR}")

    if (NOT EXISTS "${seos_project_dir}")
        message(FATAL_ERROR "project folder not found: ${seos_project_dir}")
    endif()

    add_subdirectory("${seos_project_dir}" "seos_system")

endmacro()


#-------------------------------------------------------------------------------
# build script
#-------------------------------------------------------------------------------

if (NOT SEOS_SANDBOX_PASSIVE_CMAKE)

    if (SEOS_SANDBOX_DOC)

        seos_sandbox_build_doc()

    else()

        if (NOT SEOS_PROJECT_DIR)
            message(FATAL_ERROR "please set SEOS_PROJECT_DIR")
        endif()

        seos_sandbox_build(${SEOS_PROJECT_DIR})

    endif()

endif()
