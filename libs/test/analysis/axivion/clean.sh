#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Clean the analysis project.
#-------------------------------------------------------------------------------

# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# set common paths
source ${SCRIPT_DIR}/set_axivion_config


#-------------------------------------------------------------------------------
# Remove build dir
#-------------------------------------------------------------------------------

rm ${BUILD_DIR} -rf
