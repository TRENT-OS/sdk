cmake_minimum_required(VERSION 3.7.2)

set(OS_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}")

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

SET(SEOS_LIBS_DIR "${OS_SDK_DIR}/projects/libs")
SET(SEOS_COMPONENTS_DIR "${OS_SDK_DIR}/components")

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

    set(DEBUG_CONFIG_H_FILE             "${seos_cfg_file_abs}" CACHE STRING "")
    set(MEMORY_CONFIG_H_FILE            "${seos_cfg_file_abs}" CACHE STRING "")
    set(LOGS_CONFIG_H_FILE              "${seos_cfg_file_abs}" CACHE STRING "")
    set(KEYSTORE_CONFIG_H_FILE          "${seos_cfg_file_abs}" CACHE STRING "")
    set(FILESYSTEM_CONFIG_H_FILE        "${seos_cfg_file_abs}" CACHE STRING "")
    set(PARTITION_MANAGER_CONFIG_H_FILE "${seos_cfg_file_abs}" CACHE STRING "")
    set(OS_Logger_CONFIG_H_FILE         "${seos_cfg_file_abs}" CACHE STRING "")

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
            SEOS_CHANMUX
            SEOS_LIBS_LOGGER
            SEOS_NETWORK_DRIVER_TAP_PROXY
            SEOS_NW_STACK
            SEOS_CRYPTO
            SEOS_CRYPTO_WITH_RPC_SERVER
            SEOS_CRYPTO_WITH_RPC_CLIENT
            SEOS_TLS
            SEOS_TLS_WITH_RPC_SERVER
            SEOS_TLS_WITH_RPC_CLIENT
            SEOS_KEYSTORE
            SEOS_PARTITION_MANAGER
            SEOS_FILESYSTEM_CORE
            SEOS_FILESYSTEM_FAT
            SEOS_FILESYSTEM_SPIFFS
            SEOS_FILESYSTEM_SPIFFS_LEGACY
            SEOS_CONFIGURATION
            SEOS_LOGGER
            3RDPARTY_MBEDTLS_WITH_CRYPTO_ONLY
            3RDPARTY_MBEDTLS
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
macro(os_sdk_build_doc)

    seos_use_libs(
        SEOS_LIBS
        SEOS_CHANMUX
        SEOS_CONFIGURATION
        SEOS_CRYPTO
        SEOS_TLS
        SEOS_KEYSTORE
        SEOS_FILESYSTEM_SPIFFS
        SEOS_NW_STACK
        SEOS_PARTITION_MANAGER
        SEOS_FILESYSTEM_CORE
        SEOS_FILESYSTEM_FAT
        SEOS_LOGGER
    )

    add_subdirectory(${SEOS_LIBS_DIR})

    add_custom_target( os_sdk_doc )

    add_dependencies( os_sdk_doc
        seos_core_api_doc
        seos_chanmux_doc
        seos_libs_doc
        seos_crypto_doc
        seos_configuration_doc
        seos_tls_doc
        seos_keystore_doc
        seos_filesystem_spiffs_doc
        seos_nw_lib_doc
        seos_filesystem_core_doc
        seos_filesystem_fat_doc
        seos_partition_manager_doc
        seos_logger_doc
    )

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/seos-api-index.html
        "<!doctype html>\n"
        "<html>\n"
        "  <head></head>\n"
        "  <body>\n"
        "    <ul>\n"
        "    <li><a href=\"seos_core_api/index.html\">Core API</a></li>\n"
        "    <li><a href=\"seos_crypto/index.html\">Crypto</a></li>\n"
        "    <li><a href=\"seos_configuration/index.html\">ConfigService</a></li>\n"
        "    <li><a href=\"chanmux/index.html\">ChanMux</a></li>\n"
        "    <li>\n"
        "        <a href=\"seos_filesystem_core/index.html\">Filesystem Core</a>\n"
        "        <ul>\n"
        "        <li><a href=\"seos_filesystem_fat/index.html\">Filesystem FAT</a></li>\n"
        "        <li><a href=\"seos_filesystem_spiffs/index.html\">Filesystem SPIFFS</a></li>\n"
        "        </ul>\n"
        "    </li>\n"
        "    <li><a href=\"seos_keystore/index.html\">Keystore</a></li>\n"
        "    <li><a href=\"seos_libs/index.html\">Libs</a></li>\n"
        "    <li><a href=\"seos_logger/index.html\">Logger</a></li>\n"
        "    <li><a href=\"seos_nwstack/index.html\">Network Stack</a></li>\n"
        "    <li><a href=\"seos_partition_manager/index.html\">Partition Manager</a></li>\n"
        "    </ul>\n"
        "  </body>\n"
        "</html>\n"
    )

endmacro()


#-------------------------------------------------------------------------------
macro(DeclareAndCreateCamkESSystem camkes_system_file)

    DeclareCAmkESRootserver(
        ${camkes_system_file}
        CPP_INCLUDES
            ${SYSTEM_PROJECT_DIR}
            ${SEOS_COMPONENTS_DIR}
        CPP_FLAGS
            -DCAMKES_TOOL_PROCESSING
    )

    GenerateCAmkESRootServer()

endmacro()


#-------------------------------------------------------------------------------
macro(os_sdk_build system_project_dir)

    #---------------------------------------------------------------------------
    # SEOS default settings for a seL4 based CAmkES system.
    #---------------------------------------------------------------------------

    set(SEL4_CONFIG_DEFAULT_ADVANCED ON)

    set(RELEASE OFF CACHE BOOL "Performance optimized build")
    set(SIMULATION ON CACHE BOOL "Try and use simulable features")
    set(VERIFICATION OFF CACHE BOOL "Only verification friendly kernel features")

    # we need one scheduling domain only
    set(KernelNumDomains 1 CACHE STRING "" FORCE)

    # default is 12, which gives 4096 (2^12) slots. That is not enough for more
    # complex systems. Using 15 gives 32768 slots
    set(KernelRootCNodeSizeBits 15 CACHE STRING "" FORCE)

    # defaults is 4096, which is too small for more complex systems. What must
    # hold is: CapDLLoaderMaxObjects + Systemcaps < 2^KernelRootCNodeSizeBits
    set(CapDLLoaderMaxObjects 25000 CACHE STRING "" FORCE)

    # use ZF_LOG_DEBUG (2), useful for capdl-loader-app to to get information
    # about the required capability slots
    set(LibUtilsDefaultZfLogLevel 2 CACHE STRING "" FORCE)

    #---------------------------------------------------------------------------
    # use the seL4/CAmkES build system
    #---------------------------------------------------------------------------

    set(SDK_SEL4_CAMKES_DIR "${OS_SDK_DIR}/sdk-sel4-camkes")
    include("${SDK_SEL4_CAMKES_DIR}/helper.cmake")

    #---------------------------------------------------------------------------
    # SEOS specific build process
    #---------------------------------------------------------------------------

    CAmkESAddImportPath(
        ${SEOS_LIBS_DIR}/seos_core_api/camkes
        ${SEOS_COMPONENTS_DIR}
        ${SEOS_LIBS_DIR}/chanmux/camkes
    )

    # enable linting by default
    set(ENABLE_LINT ON CACHE BOOL "enable linting")

    if (ENABLE_LINT)
        set(CMAKE_C_CPPCHECK "cppcheck;--enable=warning;--inline-suppr")
        set(CMAKE_C_CLANG_TIDY "clang-tidy;-checks=*")
    endif()

    add_subdirectory("${SEOS_LIBS_DIR}")
    include("${SEOS_COMPONENTS_DIR}/ChanMux/CMakeLists.txt")
    include("${SEOS_COMPONENTS_DIR}/NIC_ChanMux/CMakeLists.txt")
    include("${SEOS_COMPONENTS_DIR}/UART/CMakeLists.txt")

    if (NOT EXISTS "${system_project_dir}")
        message(FATAL_ERROR "project folder not found: ${system_project_dir}")
    endif()

    set(SYSTEM_PROJECT_DIR ${system_project_dir})
    add_subdirectory("${system_project_dir}" "os_system")

    # dump SEOS system image for debugging purposes. It's mostly for low level
    # debugging of specific platform issues. For debugging an actual CAmkES
    # system that runs on top of seL4 this does not provide anything.
    set(IMAGE_NAME "$<TARGET_PROPERTY:rootserver_image,IMAGE_NAME>")
    add_custom_target(
        seos_image_dump ALL
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
