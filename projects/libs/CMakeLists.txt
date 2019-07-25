cmake_minimum_required(VERSION 3.7.2)

if (SEOS_LIBS)
    add_subdirectory(seos_libs)
endif()

if (SEOS_CRYPTO)
    add_subdirectory(seos_crypto)
endif()

if (SEOS_KEYSTORE)
    add_subdirectory(seos_keystore)
endif()
