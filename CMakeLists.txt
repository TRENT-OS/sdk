#
# SDK Build System
#
# Copyright (C) 2019-2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)

set(OS_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}")
set(OS_LIBS_DIR "${OS_SDK_DIR}/libs")
set(OS_COMPONENTS_DIR "${OS_SDK_DIR}/components")


#-------------------------------------------------------------------------------
function(os_set_config_file cfg_file)

    # ensure the file name with absolute path is used, so include files can be
    # used from projects in arbitrary directories.
    get_filename_component(CFG_FILE_ABS ${cfg_file} ABSOLUTE)

    if (NOT EXISTS "${CFG_FILE_ABS}")
         message(FATAL_ERROR "system config file not found: ${CFG_FILE_ABS}")
    endif()

    # set the variables, but do not overwrite anything in the cache. This has
    # the advantage that the user can configure the config files on the command
    # line when initializing the build. However, the drawback is that since the
    # cache is persisted over the builds, the variables will not be updated
    # when things change. So any internal changes in the SDK require a wipe of
    # the build workspace, a clean re-initialization of CMake and then a full
    # re-build.
    set(DEBUG_CONFIG_H_FILE             "${CFG_FILE_ABS}" CACHE STRING "")
    set(MEMORY_CONFIG_H_FILE            "${CFG_FILE_ABS}" CACHE STRING "")
    set(LOGS_CONFIG_H_FILE              "${CFG_FILE_ABS}" CACHE STRING "")
    set(KEYSTORE_CONFIG_H_FILE          "${CFG_FILE_ABS}" CACHE STRING "")
    set(FILESYSTEM_CONFIG_H_FILE        "${CFG_FILE_ABS}" CACHE STRING "")
    set(PARTITION_MANAGER_CONFIG_H_FILE "${CFG_FILE_ABS}" CACHE STRING "")
    set(OS_Logger_CONFIG_H_FILE         "${CFG_FILE_ABS}" CACHE STRING "")

endfunction()


#-------------------------------------------------------------------------------
function(os_use_libs)

    # we maintain a list of libs here that the SDK provides. This allows doing
    # a nice sanity check against what the system projects are trying to use.
    # While this makes it quite impossible to sneak new lib in, there is the
    # additional effort when adding new libs. We may remove this list if it
    # turn out to cause more pain than benefit.
    set(SDK_KNOWN_LIBS
            OS_LIBS
            OS_CHANMUX
            OS_LIBS_LOGGER
            OS_CERT
            OS_CRYPTO
            OS_CRYPTO_WITH_RPC_SERVER
            OS_CRYPTO_WITH_RPC_CLIENT
            OS_TLS
            OS_TLS_WITH_RPC_SERVER
            OS_TLS_WITH_RPC_CLIENT
            OS_KEYSTORE
            OS_PARTITION_MANAGER
            OS_FILESYSTEM_CORE
            OS_FILESYSTEM_FAT
            OS_FILESYSTEM_SPIFFS
            OS_FILESYSTEM_SPIFFS_LEGACY
            OS_CONFIGURATION
            OS_LOGGER
            3RDPARTY_MBEDTLS_FOR_CRYPTO
            3RDPARTY_MBEDTLS_FOR_TLS
            3RDPARTY_MBEDTLS_FOR_CERT
            THIRD_PARTY_TINYFRAME
    )

    foreach(sdk_lib ${ARGN})

        if (NOT "${sdk_lib}" IN_LIST SDK_KNOWN_LIBS)
            message(FATAL_ERROR "unknown SDK library: ${sdk_lib}")
        endif()

        # we use "FORCE" here because this must overwrite any setting from the
        # cache, e.g. from CMake configuration passed on the command line. Any
        # lib that is passed to this function must be enabled.
        set(${sdk_lib} ON CACHE BOOL "use ${sdk_lib}" FORCE)

    endforeach()

endfunction()


#-------------------------------------------------------------------------------
# provide a way how libraries can create a documentation build target. Their
# Doxyfile use DOXYGEN_OUTPUT_DIR env variable. The macro has two string
# parameters that accept shell script snippets that will run a pre and post
# build steps for the doxygen run.
macro(os_create_doxygen_target doc_target_name pre_action post_action)

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
macro(os_sdk_build_doc)

    os_use_libs(
        OS_LIBS
        OS_CHANMUX
        OS_CONFIGURATION
        OS_CRYPTO
        OS_TLS
        OS_KEYSTORE
        OS_FILESYSTEM_SPIFFS
        OS_PARTITION_MANAGER
        OS_FILESYSTEM_CORE
        OS_FILESYSTEM_FAT
        OS_LOGGER
    )

    add_subdirectory(${OS_LIBS_DIR})

    add_custom_target( os_sdk_doc )

    add_dependencies( os_sdk_doc
        os_core_api_doc
        os_chanmux_doc
        os_libs_doc
        os_crypto_doc
        os_configuration_doc
        os_tls_doc
        os_keystore_doc
        os_filesystem_spiffs_doc
        os_network_stack_doc
        os_filesystem_core_doc
        os_filesystem_fat_doc
        os_partition_manager_doc
        os_logger_doc
    )

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/os-api-index.html
        "<!doctype html>\n"
        "<html>\n"
        "  <head></head>\n"
        "  <body>\n"
        "    <ul>\n"
        "    <li><a href=\"os_core_api/index.html\">Core API</a></li>\n"
        "    <li><a href=\"os_crypto/index.html\">Crypto</a></li>\n"
        "    <li><a href=\"os_configuration/index.html\">ConfigService</a></li>\n"
        "    <li><a href=\"chanmux/index.html\">ChanMux</a></li>\n"
        "    <li>\n"
        "        <a href=\"os_filesystem_core/index.html\">Filesystem Core</a>\n"
        "        <ul>\n"
        "        <li><a href=\"os_filesystem_fat/index.html\">Filesystem FAT</a></li>\n"
        "        <li><a href=\"os_filesystem_spiffs/index.html\">Filesystem SPIFFS</a></li>\n"
        "        </ul>\n"
        "    </li>\n"
        "    <li><a href=\"os_keystore/index.html\">Keystore</a></li>\n"
        "    <li><a href=\"os_libs/index.html\">Libs</a></li>\n"
        "    <li><a href=\"os_logger/index.html\">Logger</a></li>\n"
        "    <li><a href=\"os_network_stack/index.html\">Network Stack</a></li>\n"
        "    <li><a href=\"os_partition_manager/index.html\">Partition Manager</a></li>\n"
        "    </ul>\n"
        "  </body>\n"
        "</html>\n"
    )

endmacro()


#-------------------------------------------------------------------------------
macro(DeclareAndCreateCamkESSystem camkes_system_file)

    DeclareCAmkESRootserver(
        ${camkes_system_file}
        CPP_FLAGS
            -DCAMKES_TOOL_PROCESSING
    )

    GenerateCAmkESRootServer()

endmacro()


#-------------------------------------------------------------------------------
macro(os_sdk_build system_project_dir)

    #---------------------------------------------------------------------------
    # default settings for the SDK
    #---------------------------------------------------------------------------

    # enable CAmkES by default
    set(SDK_USE_CAMKES ON CACHE BOOL "enable CAmkES")

    # enable linting by default
    set(ENABLE_LINT ON CACHE BOOL "enable linting")


    #---------------------------------------------------------------------------
    # default settings for a seL4 based CAmkES system.
    #---------------------------------------------------------------------------

    set(SEL4_CONFIG_DEFAULT_ADVANCED ON)

    set(RELEASE OFF CACHE BOOL "Performance optimized build")
    set(SIMULATION ON CACHE BOOL "Try and use simulable features")
    set(VERIFICATION OFF CACHE BOOL "Only verification friendly kernel features")

    # we need one scheduling domain only
    set(KernelNumDomains 1 CACHE STRING "")

    # default is 12, which gives 4096 (2^12) slots. That is not enough for more
    # complex systems. Using 15 gives 32768 slots
    set(KernelRootCNodeSizeBits 15 CACHE STRING "")

    if (SDK_USE_CAMKES)

        # defaults is 4096, which is too small for more complex systems. The
        # root C-Node must provide enough space for all caps in the end, ie
        # CapDLLoaderMaxObjects + Systemcaps < 2^KernelRootCNodeSizeBits
        set(CapDLLoaderMaxObjects 25000 CACHE STRING "")

    endif()

    # use ZF_LOG_DEBUG (2), useful for capdl-loader-app to to get information
    # about the required capability slots
    set(LibUtilsDefaultZfLogLevel 2 CACHE STRING "")


    #---------------------------------------------------------------------------
    # use the seL4/CAmkES build system
    #---------------------------------------------------------------------------

    set(SDK_SEL4_CAMKES_DIR "${OS_SDK_DIR}/sdk-sel4-camkes")
    include("${SDK_SEL4_CAMKES_DIR}/helper.cmake")
    setup_sel4_build_system()


    #---------------------------------------------------------------------------
    # SDK specific build process
    #---------------------------------------------------------------------------

    if (SDK_USE_CAMKES)

        setup_sel4_camkes_build_system()

        CAmkESAddCPPInclude(
            ${OS_COMPONENTS_DIR}
        )

        CAmkESAddImportPath(
            ${OS_LIBS_DIR}/os_core_api/camkes
            ${OS_COMPONENTS_DIR}
            ${OS_LIBS_DIR}/chanmux/camkes
        )

    endif()

    # linting does not work on seL4/CAmkES code, thus we define details here,
    # after we've including the seL4/CAmkES build system.
    if (ENABLE_LINT)
        set(CMAKE_C_CPPCHECK "cppcheck;--enable=warning;--inline-suppr;--output-file=cppcheck_output.txt")
        set(CMAKE_C_CLANG_TIDY "clang-tidy;-checks=*;-export-fixes=tidy.txt")
    endif()

    add_subdirectory("${OS_LIBS_DIR}")

    # we include the components even if CAmkES is not enabled, because the may
    # provide library code that native systems can use.
    include("${OS_COMPONENTS_DIR}/ChanMux/CMakeLists.txt")
    include("${OS_COMPONENTS_DIR}/CryptoServer/CMakeLists.txt")
    include("${OS_COMPONENTS_DIR}/NIC_ChanMux/CMakeLists.txt")
    include("${OS_COMPONENTS_DIR}/TlsServer/CMakeLists.txt")
    include("${OS_COMPONENTS_DIR}/UART/CMakeLists.txt")


    #---------------------------------------------------------------------------
    # add the actual system project
    #---------------------------------------------------------------------------

    if (NOT EXISTS "${system_project_dir}")
        message(FATAL_ERROR "project folder not found: ${system_project_dir}")
    endif()

    set(SYSTEM_PROJECT_DIR ${system_project_dir})

    if (SDK_USE_CAMKES)

        CAmkESAddCPPInclude(
            ${SYSTEM_PROJECT_DIR}
        )

    endif()

    add_subdirectory("${SYSTEM_PROJECT_DIR}" "os_system")


    #---------------------------------------------------------------------------
    # add post-processing steps
    #---------------------------------------------------------------------------

    # dump system image for debugging purposes. It's mostly for low level
    # debugging of specific platform issues. For debugging an actual CAmkES
    # system that runs on top of seL4 this does not provide anything.
    set(IMAGE_NAME "$<TARGET_PROPERTY:rootserver_image,IMAGE_NAME>")
    add_custom_target(
        system_image_dump ALL
        DEPENDS ${CMAKE_BINARY_DIR}/${IMAGE_NAME}
        COMMAND ${CROSS_COMPILER_PREFIX}size ${IMAGE_NAME} | tee ${IMAGE_NAME}.size
        COMMAND ${CROSS_COMPILER_PREFIX}objdump -dht ${IMAGE_NAME} > ${IMAGE_NAME}.lst
        COMMAND ${CROSS_COMPILER_PREFIX}objdump -dghlsStx ${IMAGE_NAME} > ${IMAGE_NAME}.dump
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
        VERBATIM
    )

endmacro()


#-------------------------------------------------------------------------------
# build script
#-------------------------------------------------------------------------------

if (NOT OS_SDK_PASSIVE_CMAKE)

    if (OS_SDK_DOC)

        os_sdk_build_doc()

    else()

        if (NOT OS_PROJECT_DIR)
            message(FATAL_ERROR "please set OS_PROJECT_DIR")
        endif()

        os_sdk_build(${OS_PROJECT_DIR})

    endif()

endif()
