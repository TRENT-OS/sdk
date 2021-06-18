#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Build the analysis project.
#-------------------------------------------------------------------------------

# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# set common paths
source ${SCRIPT_DIR}/set_common_paths


#-------------------------------------------------------------------------------
# Ensure build dir exists
#-------------------------------------------------------------------------------

mkdir ${BUILD_DIR} -p


#-------------------------------------------------------------------------------
# CMake config
#-------------------------------------------------------------------------------

CMAKE_PARAMS=(
    -D BUILD_ANALYSIS=ON
    -G Ninja
)

cmake ${CMAKE_PARAMS[@]} -S ${SOURCE_DIR} -B ${BUILD_DIR}


#-------------------------------------------------------------------------------
# CMake build
#-------------------------------------------------------------------------------

cmake --build ${BUILD_DIR} --target analysis
