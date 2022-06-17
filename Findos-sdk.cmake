#
# SDK Build System
#
# Copyright (C) 2019-2022, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

if(NOT CMAKE_BUILD_TYPE)
    message(FATAL_ERROR "No build type selected!")
elseif (
    NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release|RelWithDebInfo|MinSizeRel)$")
    message(FATAL_ERROR "build type not supported: '${CMAKE_BUILD_TYPE}'")
endif()

set(OS_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}")
set(OS_SDK_BUILD_DIR "os-sdk")

set(SDK_SEL4_CAMKES_DIR "${OS_SDK_DIR}/sdk-sel4-camkes")
set(OS_SDK_LIBS_DIR "${OS_SDK_DIR}/libs")
set(OS_SDK_COMPONENTS_DIR "${OS_SDK_DIR}/components")


#-------------------------------------------------------------------------------
function(os_sdk_create_config_project cfg_prj_name cfg_file)

    # ensure the file name with absolute path is used, so include files can be
    # used from projects in arbitrary directories.
    get_filename_component(CFG_FILE_ABS ${cfg_file} ABSOLUTE)

    if (NOT EXISTS "${CFG_FILE_ABS}")
         message(FATAL_ERROR "OK SDK config file not found: ${CFG_FILE_ABS}")
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
    set(OS_Logger_CONFIG_H_FILE         "${CFG_FILE_ABS}" CACHE STRING "")

    # Define project that creates an interface library providing the config
    # file include paths. This allows including the config file easily.
    get_filename_component(CFG_FILE_DIR ${CFG_FILE_ABS} DIRECTORY)
    project(${cfg_prj_name} C)
    add_library(${cfg_prj_name} INTERFACE)
    target_include_directories(${cfg_prj_name} INTERFACE ${CFG_FILE_DIR})

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_create_disassembly elf_file target_base)

    set(LST_FILE "${elf_file}.lst")

    add_custom_command(
        OUTPUT "${LST_FILE}"
        DEPENDS "${elf_file}"
        COMMENT "create disassembly for ${elf_file}"
        COMMAND "${OS_SDK_DIR}/scripts/elf-dump.sh"
                -c "${CROSS_COMPILER_PREFIX}"
                -i "${elf_file}"
                -o "${LST_FILE}"
    )

    add_custom_target(
        ${target_base}_disassemble ALL
        DEPENDS "${LST_FILE}"
    )

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_get_subdirs var_subdir_list dir)

    file(GLOB children RELATIVE "${dir}" "${dir}/*")
    set(subdir_list "")
    foreach(child IN LISTS children)
        if (IS_DIRECTORY "${dir}/${child}")
            LIST(APPEND subdir_list "${child}")
        endif()
    endforeach()
    set(${var_subdir_list} "${subdir_list}" PARENT_SCOPE)

endfunction()


#-------------------------------------------------------------------------------
# This is a macro and not a function because variables will be set
macro(os_sdk_import_sel4_camkes)

    # Even if SDK_USE_CAMKES is set, this will not enable the global components
    # by default. Any project that needs them must either cherry-pick things or
    # call global_components_import_project().
    include("${SDK_SEL4_CAMKES_DIR}/helper.cmake")

endmacro()


#-------------------------------------------------------------------------------
function(os_sdk_import_core_api)

    add_subdirectory(
        "${OS_SDK_DIR}/os_core_api"
        "${OS_SDK_BUILD_DIR}/os_core_api"
        EXCLUDE_FROM_ALL
    )

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_import_libs)

    set(GROUP "libs")
    set(GROUP_BASE_DIR "${OS_SDK_LIBS_DIR}")

    if (SDK_USE_CAMKES)
        CAmkESAddCPPInclude(${GROUP_BASE_DIR})
        CAmkESAddImportPath(${GROUP_BASE_DIR})
    endif()

    # use all libs from 'libs/*' and 'libs/3rdParty/*' , exclude the 'test'
    # folder.
    os_sdk_get_subdirs(subdir_list "${GROUP_BASE_DIR}")
    list(REMOVE_ITEM subdir_list "3rdParty" "test")
    os_sdk_get_subdirs(subdir_3rdparty_list "${GROUP_BASE_DIR}/3rdParty")
    foreach(subdir IN LISTS subdir_3rdparty_list)
        list(APPEND subdir_list "3rdParty/${subdir}")
    endforeach()
    foreach(subdir IN LISTS subdir_list)
        add_subdirectory(
            "${GROUP_BASE_DIR}/${subdir}"
            "${OS_SDK_BUILD_DIR}/${GROUP}/${subdir}"
            EXCLUDE_FROM_ALL
        )
    endforeach()

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_import_components)

    set(GROUP "components")
    set(GROUP_BASE_DIR "${OS_SDK_COMPONENTS_DIR}")

    if (SDK_USE_CAMKES)
        CAmkESAddCPPInclude(${GROUP_BASE_DIR})
        CAmkESAddImportPath(${GROUP_BASE_DIR})
    endif()

    os_sdk_get_subdirs(subdir_list "${GROUP_BASE_DIR}")
    foreach(subdir IN LISTS subdir_list)
        add_subdirectory(
            "${GROUP_BASE_DIR}/${subdir}"
            "${OS_SDK_BUILD_DIR}/${GROUP}/${subdir}"
            EXCLUDE_FROM_ALL
        )
    endforeach()

endfunction()


#-------------------------------------------------------------------------------
# Add component(s) from global components
#
# Parameters:
#
#  [<COMPONENT_1> [<COMPONENT_2> ...]]
#    The components
#
function(os_sdk_import_from_global_components)

    if(NOT GLOBAL_COMPONENTS_DIR)
        # GLOBAL_COMPONENTS_DIR is set by find_package("global-components"),
        # which is done automatically when SDK_USE_CAMKES is enabled.
        message(FATAL_ERROR "global-components package missing")
    endif()

    CAmkESAddImportPath(
        "${GLOBAL_COMPONENTS_DIR}/components"
        "${GLOBAL_COMPONENTS_DIR}/plat_components/${KernelPlatform}"
    )

    foreach(comp IN LISTS ARGV)
        add_subdirectory(
            "${GLOBAL_COMPONENTS_DIR}/${comp}"
            "global_components/${comp}"
        )
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
function(os_sdk_get_all_cmake_targets var_targets dir)

    set(target_list "")
    get_property(sub_dir_list DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)
    foreach(sub_dir ${sub_dir_list})
        os_sdk_get_all_cmake_targets(sub_target_list ${sub_dir})
        list(APPEND target_list "${sub_target_list}")
    endforeach()
    get_property(dir_target_list DIRECTORY ${dir} PROPERTY BUILDSYSTEM_TARGETS)
    list(APPEND target_list "${dir_target_list}")
    set(${var_targets} "${target_list}" PARENT_SCOPE)

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_postprocess_targets)

    os_sdk_get_all_cmake_targets(targets ${CMAKE_CURRENT_SOURCE_DIR})
    # each CAmkES component is in a *.instance.bin file.
    list(FILTER targets
         INCLUDE REGEX "^.*\.instance\.bin|capdl-loader|kernel\.elf|elfloader$")
    foreach(target ${targets})
        get_target_property(BINARY_DIR ${target} BINARY_DIR)
        os_sdk_create_disassembly("${BINARY_DIR}/${target}" ${target})
    endforeach()

    set(target "rootserver_image")
    if(TARGET "${target}")
        get_target_property(IMAGE_NAME ${target} IMAGE_NAME)
        get_filename_component(IMAGE_DIR "${IMAGE_NAME}" DIRECTORY)
        # copy system image to generic file images/os_image.[bin|elf...]
        set(OS_SYS_IMG "${IMAGE_DIR}/os_image.${ElfloaderImage}")
        add_custom_command(
            OUTPUT "${OS_SYS_IMG}"
            DEPENDS "${IMAGE_NAME}"
            COMMAND ${CMAKE_COMMAND} -E copy "${IMAGE_NAME}" "${OS_SYS_IMG}"
            VERBATIM
            COMMENT "copy ${IMAGE_NAME} to ${OS_SYS_IMG}"
        )
        add_custom_target(${target}_copy ALL DEPENDS "${OS_SYS_IMG}")
        if("${ElfloaderImage}" STREQUAL "elf")
            os_sdk_create_disassembly("${OS_SYS_IMG}" ${target})
        endif()
    endif()

    set(target "capdl-loader")
    if(TARGET "${target}")
        # The CapDL Loader's build produces graph.dot with all the components,
        # create a SVG image from this.
        get_target_property(BINARY_DIR ${target} BINARY_DIR)
        set(OS_SYS_GRAPH "${BINARY_DIR}/graph.svg")
        add_custom_command(
            OUTPUT "${OS_SYS_GRAPH}"
            DEPENDS "${target}"
            COMMAND dot -Tsvg "${BINARY_DIR}/graph.dot" -o "${OS_SYS_GRAPH}"
            VERBATIM
            COMMENT "create ${OS_SYS_GRAPH}"
        )
        add_custom_target(${target}_graph ALL DEPENDS "${OS_SYS_GRAPH}")
    endif()

endfunction()


#-------------------------------------------------------------------------------
macro(os_sdk_set_defaults)

    #---------------------------------------------------------------------------
    # default settings for the SDK
    #---------------------------------------------------------------------------

    # enable CAmkES by default
    set(SDK_USE_CAMKES ON CACHE BOOL "enable CAmkES")

    # disable linting by default
    set(ENABLE_LINT OFF CACHE BOOL "enable linting")


    #---------------------------------------------------------------------------
    # default settings for a seL4 based CAmkES system.
    #---------------------------------------------------------------------------

    set(SEL4_CONFIG_DEFAULT_ADVANCED ON)

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

        # we require that the CAmkES files are run through the C pre processor
        # first, so the includes and macros get resolved
        set(CAmkESCPP ON CACHE BOOL "" FORCE)

        # use device tree
        set(CAmkESDTS ON CACHE BOOL "" FORCE)

    endif()

    # default to ZF_LOG_DEBUG (2), because ZF_LOG_INFO (3) is sometimes not
    # verbose enough. Apps and components can use ZF_LOG_LEVEL=n to tailor this
    # to their needs.
    set(LibUtilsDefaultZfLogLevel 2 CACHE STRING "")

endmacro()


#-------------------------------------------------------------------------------
# Parameters:
#
#  CONFIG_FILE <cfg_file>
#    config file, required when using certain components
#
#  CONFIG_PROJECT_NAME <name>
#    optional, create config project for config file. The project provides an
#    interface library that provides the config file's include path, so the
#    config file can be included in other files also.
#
macro(os_sdk_setup)

    cmake_parse_arguments(
        "SETUP_PARAM" # variable prefix
        "" # option arguments
        "CONFIG_FILE;CONFIG_PROJECT" # optional single value arguments
        "" # optional multi value arguments
        ${ARGN}
    )

    os_sdk_import_sel4_camkes()

    # Enable generation of CMAKE_BINARY_DIR/compile_commands.json that will
    # contain the exact compiler calls for all translation units of the project
    # to be used for static analysis later.
    # NOTE: We enable this here after all the seL4/CAmkES stuff because we only
    # want our system's stuff in the file.
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

    # NOTE: Linting does not work on seL4/CAmkES code, thus we define details
    # here after we've included the seL4/CAmkES stuff.
    if (ENABLE_LINT)
        set(CMAKE_C_CPPCHECK "cppcheck;--enable=warning;--inline-suppr")

        # NOTE: We cannot use set(CMAKE_C_CLANG_TIDY "clang-tidy;...") because
        # CMake passes the compile target architecture to clang-tidy in a wrong
        # way when crosscompiling. As a workaround we use -p to pass the
        # location of compile_commands.json to clang-tidy.
        find_program(CLANGTIDY clang-tidy)
        if(NOT CLANGTIDY)
            message(FATAL_ERROR "Didn't find clang-tidy executable!")
        endif()
        set(CMAKE_CXX_CLANG_TIDY ${CLANGTIDY} -extra-arg=-Wno-unknown-warning-option -p=${CMAKE_BINARY_DIR})
    endif()

    if(SETUP_PARAM_CONFIG_FILE)
        if(NOT SETUP_PARAM_CONFIG_PROJECT)
            get_filename_component(
                SETUP_PARAM_CONFIG_PROJECT
                ${SETUP_PARAM_CONFIG_FILE}
                NAME_WE
            )
            message("using config file project name: ${SETUP_PARAM_CONFIG_PROJECT}")
        endif()
        os_sdk_create_config_project(
            ${SETUP_PARAM_CONFIG_PROJECT}
            ${SETUP_PARAM_CONFIG_FILE}
        )
    endif()

    os_sdk_import_core_api()
    os_sdk_import_libs()
    # The components are included even if SDK_USE_CAMKES is not enabled, because
    # they contain library code that native systems can use.
    os_sdk_import_components()

endmacro()


#-------------------------------------------------------------------------------
function(os_sdk_create_system system_file)

    DeclareRootserver(${system_file})
    GenerateSimulateScript()
    os_sdk_postprocess_targets()

endfunction()


#-------------------------------------------------------------------------------
function(os_sdk_create_CAmkES_system camkes_system_file)

    # add the folder of the camkes system file to the search path, as it may
    # contain additional files.
    get_filename_component(camkes_system_root "${camkes_system_file}" DIRECTORY)
    if("${camkes_system_root}" STREQUAL "")
        set(camkes_system_root ".")
    endif()
    CAmkESAddCPPInclude("${camkes_system_root}")

    DeclareCAmkESRootserver(${camkes_system_file})
    GenerateCAmkESRootServer()
    GenerateSimulateScript()

    # Use ZF_LOG_INFO (3) for the CapDL Loader, because usually we are not
    # interested in seeing all details of the cap setup during boot. This also
    # makes the boot quite slow for large systems due to the amount of data that
    # is printed.
    target_compile_definitions("capdl-loader" PRIVATE ZF_LOG_LEVEL=3)

    os_sdk_postprocess_targets()

endfunction()


#-------------------------------------------------------------------------------
include(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(
    os-sdk
    OS_SDK_DIR
    SDK_SEL4_CAMKES_DIR)
