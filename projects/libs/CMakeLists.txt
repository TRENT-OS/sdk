#
# SDK Libraries
#
# Copyright (C) 2019-2020, Hensoldt Cyber GmbH
#

cmake_minimum_required(VERSION 3.7.2)

#-------------------------------------------------------------------------------
# This CMake file is indirectly used by various other CMake files and they may
# enable the same libs eventually. Thus we need to guard against this and
# include the library only once
#
# Parameters
#   <lib_path>
#     required, path to the library, folder must contains a CMakeLists.txt file
#
#   USAGE_FLAGS <flag_1> <flag_1> ...
#     optional, include the library only if one of these flags is set
#
function(add_sdk_lib lib_path)

    cmake_parse_arguments(
        PARSE_ARGV
        1
        LIB_CFG
        "" # Option arguments
        "" # Single arguments
        "USAGE_FLAGS" # Multiple arguments
    )

    # check if the lib is to be used. If nothing is specified the lib is used
    # unconditionallly.
    set(DO_USE_SDK_LIB FALSE)
    if (NOT LIB_CFG_USAGE_FLAGS)
        set(DO_USE_SDK_LIB TRUE)
    else()
        foreach(usage_flag in ${LIB_CFG_USAGE_FLAGS})
            if (${usage_flag})
                set(DO_USE_SDK_LIB TRUE)
                break()
            endif()
        endforeach()
    endif()


    if (DO_USE_SDK_LIB)

        get_property(ENABLED_SDK_LIBS GLOBAL PROPERTY sdk_libs)
        if (NOT "${lib_path}" IN_LIST ENABLED_SDK_LIBS)
            set_property(GLOBAL APPEND PROPERTY sdk_libs "${lib_path}")
            add_subdirectory("${lib_path}")
        endif()

    endif()

endfunction()


#-------------------------------------------------------------------------------

add_sdk_lib(
    "seos_core_api"
)

add_sdk_lib(
    "seos_libs"
    USAGE_FLAGS
        SEOS_LIBS
)

add_sdk_lib(
    "chanmux"
    USAGE_FLAGS
        SEOS_CHANMUX
)

add_sdk_lib(
    "seos_crypto"
    USAGE_FLAGS
        SEOS_CRYPTO
        SEOS_CRYPTO_WITH_RPC_SERVER
        SEOS_CRYPTO_WITH_RPC_CLIENT
)

add_sdk_lib(
    "seos_keystore"
    USAGE_FLAGS
        SEOS_KEYSTORE
)

add_sdk_lib(
    "seos_network_driver_tap_proxy"
    USAGE_FLAGS
        SEOS_NETWORK_DRIVER_TAP_PROXY
)

add_sdk_lib(
    "seos_nwstack"
    USAGE_FLAGS
        SEOS_NW_STACK
)

add_sdk_lib(
    "seos_partition_manager"
    USAGE_FLAGS
        SEOS_PARTITION_MANAGER
)

add_sdk_lib(
    "seos_filesystem_core"
    USAGE_FLAGS
        SEOS_FILESYSTEM_CORE
)

add_sdk_lib(
    "seos_filesystem_fat"
    USAGE_FLAGS
        SEOS_FILESYSTEM_FAT
)


add_sdk_lib(
    "seos_filesystem_spiffs"
    USAGE_FLAGS
        SEOS_FILESYSTEM_SPIFFS
        SEOS_FILESYSTEM_SPIFFS_LEGACY
)

add_sdk_lib(
    "seos_tls"
    USAGE_FLAGS
        SEOS_TLS
        SEOS_TLS_WITH_RPC_CLIENT
        SEOS_TLS_WITH_RPC_SERVER
)

add_sdk_lib(
    "seos_configuration"
    USAGE_FLAGS
        SEOS_CONFIGURATION
)

add_sdk_lib(
    "seos_logger"
    USAGE_FLAGS
        SEOS_LOGGER
)

add_sdk_lib(
    "seos_cert"
    USAGE_FLAGS
        SEOS_CERT
)

add_sdk_lib(
    "3rdParty/mbedtls"
    USAGE_FLAGS
        3RDPARTY_MBEDTLS_FOR_TLS
        3RDPARTY_MBEDTLS_FOR_CRYPTO
        3RDPARTY_MBEDTLS_FOR_CERT
)

add_sdk_lib(
    "3rdParty/tinyframe"
    USAGE_FLAGS
        THIRD_PARTY_TINYFRAME
)
