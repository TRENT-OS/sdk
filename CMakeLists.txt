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

include(tools/seL4/cmake-tool/default-CMakeLists.txt)
