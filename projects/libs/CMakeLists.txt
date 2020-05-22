cmake_minimum_required(VERSION 3.7.2)

add_subdirectory(seos_core_api)

if (SEOS_LIBS)
    add_subdirectory(seos_libs)
endif()

if (SEOS_CHANMUX)
    add_subdirectory(chanmux)
endif()

if (SEOS_CRYPTO OR SEOS_CRYPTO_WITH_RPC_SERVER OR SEOS_CRYPTO_WITH_RPC_CLIENT)
    add_subdirectory(seos_crypto)
endif()

if (SEOS_KEYSTORE)
    add_subdirectory(seos_keystore)
endif()

if (SEOS_NETWORK_DRIVER_TAP_PROXY)
    add_subdirectory(seos_network_driver_tap_proxy)
endif()

if (SEOS_NW_STACK)
    add_subdirectory(seos_nwstack)
endif()

if (SEOS_PARTITION_MANAGER)
    add_subdirectory(seos_partition_manager)
endif()

if (SEOS_FILESYSTEM_CORE)
    add_subdirectory(seos_filesystem_core)
endif()

if (SEOS_FILESYSTEM_FAT)
    add_subdirectory(seos_filesystem_fat)
endif()

if (SEOS_FILESYSTEM_SPIFFS OR SEOS_FILESYSTEM_SPIFFS_LEGACY)
    add_subdirectory(seos_filesystem_spiffs)
endif()

if (SEOS_TLS OR SEOS_TLS_WITH_RPC_CLIENT OR SEOS_TLS_WITH_RPC_SERVER)
    add_subdirectory(seos_tls)
endif()

if (SEOS_CONFIGURATION)
    add_subdirectory(seos_configuration)
endif()

if (SEOS_LOGGER)
    add_subdirectory(seos_logger)
endif()

if (SEOS_CERT)
    add_subdirectory(seos_cert)
endif()

if (3RDPARTY_MBEDTLS_FOR_TLS OR 3RDPARTY_MBEDTLS_FOR_CRYPTO OR 3RDPARTY_MBEDTLS_FOR_CERT)
    add_subdirectory(3rdParty/mbedtls)
endif()

if (THIRD_PARTY_TINYFRAME)
    add_subdirectory(3rdParty/tinyframe)
endif()
