cmake_minimum_required(VERSION 3.7.2)

add_subdirectory(seos_core_api)

if (SEOS_LIBS)
    add_subdirectory(seos_libs)
endif()

if (SEOS_CRYPTO)
    add_subdirectory(seos_crypto)
endif()

if (SEOS_KEYSTORE)
    add_subdirectory(seos_keystore)
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
