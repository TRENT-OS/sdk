#!/bin/bash -eu

#-------------------------------------------------------------------------------
#
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
#-------------------------------------------------------------------------------

# NOTE: This script defines the name and default tag of the TRENTOS analysis
# container and implements the startup functionality. Because the container and
# this script shall not be provided to the customer bash_functions.def should
# not contain any references to it.


# the name is fixed, but the tag can be set externally also
TRENTOS_ANALYSIS_CONTAINER_NAME="trentos_analysis"
TRENTOS_ANALYSIS_CONTAINER_TAG=${TRENTOS_ANALYSIS_CONTAINER_TAG:-20210601}
TRENTOS_ANALYSIS_CONTAINER=${TRENTOS_ANALYSIS_CONTAINER_NAME}:${TRENTOS_ANALYSIS_CONTAINER_TAG}


# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# load function definitions into current bash
source ${SCRIPT_DIR}/bash_functions.def

# set DOCKER_ARGS and ARGS
parse_command_line_arguments "$@"

DOCKER_PARAMS_ANALYSIS=(
    # add the runtime GID used for the haskell tools
    --group-add=stack

    # use devnet DNS server to resolve internal hostnames
    --dns="192.168.82.14"
    # set permissions to use SSHFS
    --cap-add SYS_ADMIN
    --device /dev/fuse
    --security-opt apparmor:unconfined
    # enable GUI to run Axivion tools
    -e DISPLAY=$DISPLAY
    -v /tmp/.X11-unix:/tmp/.X11-unix
)

# execute trentos_analysis and pass all the arguments we received
do_run_docker ${TRENTOS_ANALYSIS_CONTAINER} "${DOCKER_PARAMS_ANALYSIS[@]}"
