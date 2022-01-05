#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021-2022, HENSOLDT Cyber GmbH
#
# Build the analysis project.
#
# Usage: build.sh
#
# The environment variable ENABLE_ANALYSIS has to be set to ON if the build
# shall be executed with the Axivion Suite. Default for regular build is OFF.
#-------------------------------------------------------------------------------

# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# set common paths
source ${SCRIPT_DIR}/set_axivion_config

# Use CMake build target set in the environment variable (default: analysis).
BUILD_TARGET=${BUILD_TARGET:-analysis}


#-------------------------------------------------------------------------------
# Ensure build dir exists
#-------------------------------------------------------------------------------

mkdir ${BUILD_DIR} -p


#-------------------------------------------------------------------------------
# CMake config
#-------------------------------------------------------------------------------

ENABLE_ANALYSIS=${ENABLE_ANALYSIS:-OFF}

CMAKE_PARAMS=(
    -D BUILD_ANALYSIS=ON
    -G Ninja
)

if [[ ${ENABLE_ANALYSIS} == "ON" ]]; then

    CMAKE_PARAMS+=(
        # CMake settings for axivion suite
        -D CMAKE_TOOLCHAIN_FILE:FILEPATH=${SCRIPT_DIR}/axivion-native-toolchain.cmake
    )

fi

SOURCE_DIR="${SCRIPT_DIR}/../../.."

cmake ${CMAKE_PARAMS[@]} -S ${SOURCE_DIR} -B ${BUILD_DIR}


#-------------------------------------------------------------------------------
# CMake build
#-------------------------------------------------------------------------------

cmake --build ${BUILD_DIR} --target ${BUILD_TARGET}
