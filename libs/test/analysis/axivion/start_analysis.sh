#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Start the analysis with the Axivion Suite activated.
#-------------------------------------------------------------------------------

# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# set common paths
source ${SCRIPT_DIR}/set_common_paths


#-------------------------------------------------------------------------------
# Prepare analysis
#-------------------------------------------------------------------------------

export PROJECTNAME=LibsAnalysis

# The TARGETS variable defines the CMake build targets and outfiles for multiple
# analysis projects. Usually the targets are components of a TRENTOS system. The
# name of the analysis project will be "PROJECTNAME_TargetName".
declare -A TARGETS=(
    # [TargetName]="<BuildTarget> <OutfileInBuildDir>"
    [Main]="analysis test/analysis/libanalysis.so"
)


#-------------------------------------------------------------------------------
# Execute analysis
#-------------------------------------------------------------------------------

. ${AXIVION_COMMON_DIR}/execute_analysis.sh
