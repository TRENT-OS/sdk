#
# Axivion Suite toolchain file
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#

# force compiler ID to "GNU"
set(CMAKE_C_COMPILER_ID   GNU CACHE STRING "CMAKE_C_COMPILER_ID"   FORCE)
set(CMAKE_CXX_COMPILER_ID GNU CACHE STRING "CMAKE_CXX_COMPILER_ID" FORCE)

# set executables for axivion suite
set(CMAKE_C_COMPILER    "/opt/bauhaus-suite/bin/cafeCC")
set(CMAKE_CXX_COMPILER  "/opt/bauhaus-suite/bin/cafeCC")
set(CMAKE_ASM_COMPILER  "/opt/bauhaus-suite/bin/cafeCC")
