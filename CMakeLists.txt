cmake_minimum_required(VERSION 3.7.2)

include(tools/seL4/cmake-tool/default-CMakeLists.txt)

add_custom_target( seos_sandbox_doc )
add_dependencies( seos_sandbox_doc seos_libs_doc seos_crypto_doc seos_keystore_doc )
