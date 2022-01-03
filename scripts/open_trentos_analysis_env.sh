#!/bin/bash -eu

#-------------------------------------------------------------------------------
# Copyright (C) 2021-2022, HENSOLDT Cyber GmbH
#
# Start the analysis container for the local workflow.
#
# The script checks if the dashboard server is reachable because a local build
# needs to retrieve the latest analysis results from there.
#
# NOTE: This script defines the name and default tag of the TRENTOS analysis
# container and implements the startup functionality. Because the container and
# this script shall not be provided to the customer bash_functions.def should
# not contain any references to it.
#-------------------------------------------------------------------------------


# the name is fixed, but the tag can be set externally also
TRENTOS_ANALYSIS_CONTAINER_NAME="trentos_analysis"
TRENTOS_ANALYSIS_CONTAINER_TAG=${TRENTOS_ANALYSIS_CONTAINER_TAG:-20220103}
TRENTOS_ANALYSIS_CONTAINER=${TRENTOS_ANALYSIS_CONTAINER_NAME}:${TRENTOS_ANALYSIS_CONTAINER_TAG}


# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# load function definitions into current bash
source ${SCRIPT_DIR}/bash_functions.def


#-------------------------------------------------------------------------------
# Check devnet connection
#-------------------------------------------------------------------------------

if ! ping -c1 -W1 hc-axiviondashboard &> /dev/null; then

    echo "ERROR: Running an analysis requires devnet connection."
    echo
    exit 1

fi


#-------------------------------------------------------------------------------
# Set DOCKER_ARGS and ARGS
#-------------------------------------------------------------------------------

parse_command_line_arguments "$@"

DOCKER_PARAMS_ANALYSIS=(
    # add user to group stack (for the haskell tools)
    --group-add=stack

    # set permissions to use SSHFS
    --cap-add SYS_ADMIN
    --device /dev/fuse
    --security-opt apparmor:unconfined

    # enable GUI to run Axivion tools
    -e DISPLAY=${DISPLAY}
    -v /tmp/.X11-unix:/tmp/.X11-unix
)


#-------------------------------------------------------------------------------
# Execute trentos_analysis and pass all the arguments we received
#-------------------------------------------------------------------------------

do_run_docker ${TRENTOS_ANALYSIS_CONTAINER} "${DOCKER_PARAMS_ANALYSIS[@]}"
