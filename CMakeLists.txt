#
# SDK Build System
#
# Copyright (C) 2019-2021, HENSOLDT Cyber GmbH
#

cmake_minimum_required(VERSION 3.17)

project(system)

if (NOT CMAKE_BUILD_TYPE)
    message(FATAL_ERROR "No build type selected!")
elseif (
    NOT CMAKE_BUILD_TYPE MATCHES "^(Debug|Release|RelWithDebInfo|MinSizeRel)$")

    message(
        FATAL_ERROR "The build type '${CMAKE_BUILD_TYPE}' is not supported.")
endif()

set(OS_SDK_DIR "${CMAKE_CURRENT_LIST_DIR}")

set(SDK_SEL4_CAMKES_DIR "${OS_SDK_DIR}/sdk-sel4-camkes")
set(OS_LIBS_DIR "${OS_SDK_DIR}/libs")
set(OS_COMPONENTS_DIR "${OS_SDK_DIR}/components")


#-------------------------------------------------------------------------------
# Set the system configuration
#
# Parameters:
#
#  <cfg_file>
#    required, config file name.
#
#  CREATE_CONFIG_PROJECT
#    optional, create config project with base name of file, ie if <cfg_file>
#    is "configs/system_config.h", the project's name will be "system_config".
#    The project creates an interface library that provides the config file's
#    include path. This allows including the config file easily in other files
#    then.
#
#  CONFIG_PROJECT_NAME <name>
#    optional, allows customizing the config project's name. This parameters
#    implicitly enables CREATE_CONFIG_PROJECT, so it must not be specified
#    explicitly.
#
function(os_set_config_file cfg_file)

    cmake_parse_arguments(
        PARSE_ARGV
        1
        CFG
        "CREATE_CONFIG_PROJECT" # option arguments
        "CONFIG_PROJECT_NAME" # optional single value arguments
        "" # optional multi value arguments
    )

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
    set(OS_Logger_CONFIG_H_FILE         "${CFG_FILE_ABS}" CACHE STRING "")

    #-----------------------------------------------
    if (CFG_CONFIG_PROJECT_NAME)
        set(CFG_CREATE_CONFIG_PROJECT TRUE)
    endif()

    if (CFG_CREATE_CONFIG_PROJECT)

        if (NOT CFG_CONFIG_PROJECT_NAME)

            get_filename_component(
                CFG_CONFIG_PROJECT_NAME
                ${CFG_FILE_ABS}
                NAME_WE
            )
        endif()

        message("creating config file project: ${CFG_CONFIG_PROJECT_NAME}")

        get_filename_component(CFG_FILE_DIR ${CFG_FILE_ABS} DIRECTORY)

        # Define project that creates an interface library providing the config
        # file include paths. This allows including the config file easily.
        #
        # Note that parameter `PLATFORM` is not the same as `KernelPlatform` but
        # can be the same as e.g. `KernelARMPlatform`. Nevertheless this is the
        # top level system platform selector, which enables the portability of
        # the applications.
        project(${CFG_CONFIG_PROJECT_NAME} C)
        add_library(${PROJECT_NAME} INTERFACE)
        target_include_directories(
            ${PROJECT_NAME}
            INTERFACE
                ${CFG_FILE_DIR}
                ${CFG_FILE_DIR}/plat/${PLATFORM}
        )

    endif()

endfunction()


#-------------------------------------------------------------------------------
function(add_os_libs_subdirectories)

    if (SDK_USE_CAMKES)

        CAmkESAddCPPInclude(${OS_LIBS_DIR})
        CAmkESAddImportPath(${OS_LIBS_DIR})

    endif()

    # include every sub-folder in OS_LIBS_DIR except "3rdParty", there we
    # include all subfolders.
    file(
        GLOB
        OS_LIBS_SUBDIRS
        RELATIVE "${OS_LIBS_DIR}"
        "${OS_LIBS_DIR}/*" "${OS_LIBS_DIR}/3rdParty/*"
    )

    list(REMOVE_ITEM OS_LIBS_SUBDIRS "3rdParty")

    foreach(ITEM IN LISTS OS_LIBS_SUBDIRS)
        set(SUBDIR "${OS_LIBS_DIR}/${ITEM}")
        # list can also contain files, e.g. ctag index files,  but we only
        # care about the folders
        if (IS_DIRECTORY "${SUBDIR}")
            add_subdirectory("${SUBDIR}" "libs/${ITEM}")
        endif()
    endforeach()

endfunction()


#-------------------------------------------------------------------------------
function(include_os_components)

    if (SDK_USE_CAMKES)

        CAmkESAddCPPInclude(${OS_COMPONENTS_DIR})
        CAmkESAddImportPath(${OS_COMPONENTS_DIR})

    endif()

    # include every sub-folder in OS_COMPONENTS_DIR except 3rdParty
    file(
        GLOB
        OS_COMPONENTS_SUBDIRS
        RELATIVE "${OS_COMPONENTS_DIR}"
        "${OS_COMPONENTS_DIR}/*")

    foreach(ITEM IN LISTS OS_COMPONENTS_SUBDIRS)
        set(SUBDIR "${OS_COMPONENTS_DIR}/${ITEM}")
        # list can also contain files, e.g. ctag index files,  but we only
        # care about the folders
        if (IS_DIRECTORY "${SUBDIR}")
            # Components aren't CMake projects, their CMakeLists.txt files
            # contain functions that must be called to create the actual
            # component's CMake project. Thus we can't use add_subdirectory()
            # here but must use include(). The included CMake files are executed
            # in the same scope and thus can modify variables and add functions.
            include("${SUBDIR}/CMakeLists.txt")
        endif()

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
macro(get_all_targets_recursive targets dir)

    get_property(subdirectories DIRECTORY ${dir} PROPERTY SUBDIRECTORIES)
    foreach(subdir ${subdirectories})
        get_all_targets_recursive(${targets} ${subdir})
    endforeach()

    get_property(current_targets DIRECTORY ${dir} PROPERTY BUILDSYSTEM_TARGETS)
    list(APPEND ${targets} ${current_targets})

endmacro()


#-------------------------------------------------------------------------------
function(create_disassembly elf_file target_base)

    set(LST_FILE "${elf_file}.lst")

    add_custom_command(
        OUTPUT "${LST_FILE}"
        DEPENDS "${elf_file}"
        COMMAND ${CROSS_COMPILER_PREFIX}objdump -dhSt "${elf_file}" > "${LST_FILE}"
        VERBATIM
        COMMENT "create disassembly for ${elf_file}"
    )

    add_custom_target(
        ${target_base}_disassemble ALL
        DEPENDS "${LST_FILE}"
    )

endfunction()


#-------------------------------------------------------------------------------
function(DeclareAndCreateCamkESSystem camkes_system_file)

    DeclareCAmkESRootserver(${camkes_system_file})

    GenerateCAmkESRootServer()

    set(targets "")
    get_all_targets_recursive(targets ${CMAKE_CURRENT_SOURCE_DIR})
    foreach(target ${targets})

        # each CAmkES component is in a *.instance.bin file.
        if(target MATCHES "^(.*\.instance\.bin|capdl-loader)$")

            get_target_property(BINARY_DIR ${target} BINARY_DIR)
            create_disassembly("${BINARY_DIR}/${target}" ${target})

        endif()

        if(target STREQUAL "capdl-loader")

            # Use debug level INFO (3) for the CapDL Loader, because usually we
            # are not interested in seeing all details the cap setup during
            # boot. This also makes the boot quite slow for large systems due
            # to the amount of data that is printed.
            target_compile_definitions(
                ${target}
                PRIVATE
                    ZF_LOG_LEVEL=3
            )

            # the CapDL Loader's build produces graph.dot with all the
            # components, create a SVG image from this.
            add_custom_command(
                TARGET ${target}
                POST_BUILD
                COMMAND dot -Tsvg graph.dot -o graph.svg
                WORKING_DIRECTORY "$<TARGET_PROPERTY:${target},BINARY_DIR>"
                VERBATIM
                COMMENT "create system picture"
            )

        endif()

    endforeach()

endfunction()


#-------------------------------------------------------------------------------
macro(os_sdk_build system_project_dir)

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

    # use ZF_LOG_DEBUG (2) by default, apps and components can change this
    set(LibUtilsDefaultZfLogLevel 2 CACHE STRING "")


    #---------------------------------------------------------------------------
    # use the seL4/CAmkES build system
    #---------------------------------------------------------------------------

    # Even if SDK_USE_CAMKES is set, this will not enable the global components
    # by default. Any project that needs them must either cherry-pick things or
    # call global_components_import_project().
    include("${SDK_SEL4_CAMKES_DIR}/helper.cmake")


    #---------------------------------------------------------------------------
    # SDK specific build process
    #---------------------------------------------------------------------------

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

    add_subdirectory("${OS_SDK_DIR}/os_core_api" "os_core_api")
    add_os_libs_subdirectories()

    # We include the components even if CAmkES is not enabled, because they may
    # provide library code that native systems can use.
    include_os_components()


    #---------------------------------------------------------------------------
    # add the actual system project
    #---------------------------------------------------------------------------

    if (NOT EXISTS "${system_project_dir}")
        message(FATAL_ERROR "project folder not found: ${system_project_dir}")
    endif()

    if (SDK_USE_CAMKES)

        # Note that parameter `PLATFORM` is not the same as `KernelPlatform` but
        # can be the same as e.g. `KernelARMPlatform`. Nevertheless this is the
        # top level system platform selector, which enables the portability of
        # the applications.
        CAmkESAddCPPInclude(
            ${system_project_dir}
            ${system_project_dir}/plat/${PLATFORM}
        )

    endif()

    add_subdirectory("${system_project_dir}" "os_system")

    set(targets "")
    get_all_targets_recursive(targets ${CMAKE_CURRENT_SOURCE_DIR})
    foreach(target ${targets})

        if(target MATCHES "^(elfloader|kernel\.elf)$")

            get_target_property(BINARY_DIR ${target} BINARY_DIR)
            create_disassembly("${BINARY_DIR}/${target}" ${target})

        endif()

        if(target STREQUAL "rootserver_image")

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
            add_custom_target(
                ${target}_copy ALL
                DEPENDS "${OS_SYS_IMG}"
            )

            if("${ElfloaderImage}" STREQUAL "elf")

                create_disassembly("${OS_SYS_IMG}" ${target})

            endif()

        endif()

    endforeach()

endmacro()


#-------------------------------------------------------------------------------
# build script
#-------------------------------------------------------------------------------

if (NOT OS_SDK_PASSIVE_CMAKE)

    if (NOT OS_PROJECT_DIR)
        message(FATAL_ERROR "please set OS_PROJECT_DIR")
    endif()

    os_sdk_build(${OS_PROJECT_DIR})

endif()
