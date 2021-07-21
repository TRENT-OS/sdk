#!/bin/bash -eu

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Start the analysis container for the local workflow.
#
# The container will be started using the ssh keys of the current user to run a
# local build. Also the local build requires a devnet connection to communicate
# with the dashboard server what will be checked in the start analysis script.
#
# NOTE: This script defines the name and default tag of the TRENTOS analysis
# container and implements the startup functionality. Because the container and
# this script shall not be provided to the customer bash_functions.def should
# not contain any references to it.
#-------------------------------------------------------------------------------


# the name is fixed, but the tag can be set externally also
TRENTOS_ANALYSIS_CONTAINER_NAME="trentos_analysis"
TRENTOS_ANALYSIS_CONTAINER_TAG=${TRENTOS_ANALYSIS_CONTAINER_TAG:-20210601}
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
    # add the runtime GID used for the haskell tools
    --group-add=stack

    # set permissions to use SSHFS
    --cap-add SYS_ADMIN
    --device /dev/fuse
    --security-opt apparmor:unconfined

    # enable GUI to run Axivion tools
    -e DISPLAY=${DISPLAY}
    -v /tmp/.X11-unix:/tmp/.X11-unix

    # use devnet DNS server to resolve internal/external hostnames (e.g.
    # hc-axiviondashboard, git-server, bitbucket.hensoldt-cyber.systems)
    --dns="192.168.82.14"

    # mount ssh keys of current user and overwrite .ssh folder in container
    -v ~/.ssh:/home/user/.ssh:ro
)


#-------------------------------------------------------------------------------
# Execute trentos_analysis and pass all the arguments we received
#-------------------------------------------------------------------------------

do_run_docker ${TRENTOS_ANALYSIS_CONTAINER} "${DOCKER_PARAMS_ANALYSIS[@]}"
