#!/bin/bash -eu

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Start the analysis container for the corresponding workflow.
#
# ENABLE_CI_BUILD has to be set to ON to activate a CI build which requires a
# devnet connection. If not set the container will be started for a local CI
# build using the ssh keys of the current user (instead of the keys prepared in
# the container).
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
# Prepare variables for workflow decision
#-------------------------------------------------------------------------------

# check if CI build enabled (ON/OFF), default is OFF
ENABLE_CI_BUILD=${ENABLE_CI_BUILD:-OFF}

# check devnet connection (ON/OFF)
DEVNET_CONNECTION=OFF
ping -c1 -W1 hc-axiviondashboard &> /dev/null && DEVNET_CONNECTION=ON


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
    -e DISPLAY=$DISPLAY
    -v /tmp/.X11-unix:/tmp/.X11-unix

    # set environment variables for analysis
    -e ENABLE_CI_BUILD=$ENABLE_CI_BUILD
    -e DEVNET_CONNECTION=$DEVNET_CONNECTION
)


#-------------------------------------------------------------------------------
# Set workflow dependent DOCKER_ARGS and ARGS
#-------------------------------------------------------------------------------

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    #---------------------------------------------------------------------------
    # CI build (with devnet connection)
    #---------------------------------------------------------------------------

    if [[ ${DEVNET_CONNECTION} != "ON" ]]; then

        echo -e "\nERROR: Starting analysis container for CI build requires devnet connection.\n"
        exit 1

    fi

    echo -e "\nStarting analysis container for CI build (devnet connection: ${DEVNET_CONNECTION}).\n"

else

    #---------------------------------------------------------------------------
    # Local CI build (with or without devnet connection)
    #---------------------------------------------------------------------------

    echo -e "\nStarting analysis container for local CI build (devnet connection: ${DEVNET_CONNECTION}).\n"

    # set ssh keys of current user if no CI build
    DOCKER_PARAMS_ANALYSIS+=(
        # mount ssh keys of current user and overwrite .ssh folder in container
        -v ~/.ssh:/home/user/.ssh:ro
    )

fi

if [[ ${DEVNET_CONNECTION} == "ON" ]]; then

    DOCKER_PARAMS_ANALYSIS+=(
        # use devnet DNS server to resolve internal/external hostnames (e.g.
        # hc-axiviondashboard, git-server, bitbucket.hensoldt-cyber.systems)
        --dns="192.168.82.14"
    )

else

    DOCKER_PARAMS_ANALYSIS+=(
        # use public DNS server to resolve external hostnames (e.g.
        # bitbucket.hensoldt-cyber.systems)
        --dns="1.1.1.1"
    )

fi


#-------------------------------------------------------------------------------
# Execute trentos_analysis and pass all the arguments we received
#-------------------------------------------------------------------------------

do_run_docker ${TRENTOS_ANALYSIS_CONTAINER} "${DOCKER_PARAMS_ANALYSIS[@]}"
