cmake_minimum_required(VERSION 3.7.2)

if (SEOS_SANDBOX_DOC)
    set(SEOS_LIBS ON CACHE BOOL "Enable seos_libs build")
    set(SEOS_CRYPTO ON CACHE BOOL "Enable seos_crypto_build")
    set(SEOS_KEYSTORE ON CACHE BOOL "Enable seos_keystore build")
    set(SEOS_NW_STACK ON CACHE BOOL "Enable seos_nw_stack build")

    add_custom_target( seos_sandbox_doc )
    add_dependencies( seos_sandbox_doc
        seos_libs_doc
        seos_crypto_doc
        seos_keystore_doc
    )
endif()

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
    # allows doing a nice sanity check agains what the SEOS projects a trying
    # to use. While this makes it quite impossible to sneak new lib in, there
    # is the additional effort when adding new libs. We may remove this list if
    # it turn out to cause more pain than benefit.
    set(SEOS_KNOWN_LIBS
            SEOS_LIBS
            SEOS_LIBS_LOGGER
            SEOS_NW_STACK
            SEOS_CRYPTO
            SEOS_CRYPTO_IMPL_MBEDTLS
            SEOS_KEYSTORE
            SPIFFS
    )

    foreach(seos_lib ${ARGN})

        if (NOT "${seos_lib}" IN_LIST SEOS_KNOWN_LIBS)
            message(FATAL_ERROR "unknown SEOS library: ${seos_lib}")
        endif()

        set(${seos_lib} ON CACHE BOOL "use ${seos_lib}" FORCE)

    endforeach()

endmacro()


#-------------------------------------------------------------------------------
# seL4 generic build system
#-------------------------------------------------------------------------------

# we can't include tools/seL4/cmake-tool/default-CMakeLists.txt here (which
# includes all.cmake from the same folder, that does the actual job), but have
# to do the steps manually and inject the caller's project in between.
include("tools/seL4/cmake-tool/settings.cmake")
include("tools/seL4/cmake-tool/base.cmake")
include("tools/seL4/cmake-tool/projects.cmake")

# inject the caller's project. It must be done before configuration.cmake is
# called, otherwise all default configuration setttigs are missing and the
# build fails. With BUILD_PROJECT the caller tells us, where it is. It can be a
# location outside of the seL4/CAmkES folder, thus we have to set the output
# folder explicitly. There is "projects/" already for the seL4/CAmkES stuff, so
# we can add the caller's project there nicely.
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
