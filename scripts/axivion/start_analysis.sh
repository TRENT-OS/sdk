#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Starts the static code analysis with the Axivion Suite for the given Axivion
# configuration directory of an analysis project.
#
# Running an analysis requires a devnet connection for communication with the
# dashboard server.
#
# Usage: start_analysis.sh config_dir [sandbox_dir] [repo_dir]
#     config_dir  Project specific axivion configuration directory.
#     sandbox_dir Sandbox directory containing 'build-system.sh' (default: seos_sandbox).
#     repo_dir    Repo folder containing '.git' (default: cwd).
#-------------------------------------------------------------------------------

# get the directory the script is located in
COMMON_CONFIG_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"


#-------------------------------------------------------------------------------
# Get arguments / show usage information
#-------------------------------------------------------------------------------

CONFIG_DIR=${1:-}
SANDBOX_DIR=${2:-"seos_sandbox"}
REPO_DIR=${3:-$(pwd)}

USAGE_INFO="Usage: $(basename $0) config_dir [sandbox_dir] [repo_dir]
    config_dir  Project specific axivion configuration directory.
    sandbox_dir Sandbox directory containing 'build-system.sh' (default: seos_sandbox).
    repo_dir    Repo folder containing '.git' (default: cwd)."

if [ $# -lt 1 ]; then
    echo "${USAGE_INFO}"
    exit 1
fi

if [ ! -x "${CONFIG_DIR}/set_axivion_config" ]; then
    echo "Invalid argument: CONFIG_DIR=${CONFIG_DIR} does not contain 'set_axivion_config'."
    echo
    echo "${USAGE_INFO}"
    exit 1
fi

if [ ! -x "${SANDBOX_DIR}/build-system.sh" ]; then
    echo "Invalid argument: SANDBOX_DIR=${SANDBOX_DIR} does not contain 'build-system.sh'."
    echo
    echo "${USAGE_INFO}"
    exit 1
fi

if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "Invalid argument: REPO_DIR=${REPO_DIR} does not contain '.git'."
    echo
    echo "${USAGE_INFO}"
    exit 1
fi


#-------------------------------------------------------------------------------
# Prepare analysis
#-------------------------------------------------------------------------------

source ${CONFIG_DIR}/set_axivion_config


#-------------------------------------------------------------------------------
# Prepare workflow
#-------------------------------------------------------------------------------

ENABLE_CI_BUILD=${ENABLE_CI_BUILD:-OFF}

# set configuration values
export AXIVION_CONFIG_DIR=$(realpath ${CONFIG_DIR})
export BAUHAUS_CONFIG="${AXIVION_CONFIG_DIR}:$(realpath ${COMMON_CONFIG_DIR})"

export AXIVION_DASHBOARD_URL=http://hc-axiviondashboard:9090/axivion

LOCAL_FILESTORAGE_DIR=/home/user/filestorage
export AXIVION_DATABASES_DIR=${LOCAL_FILESTORAGE_DIR}
SERVER_FILESTORAGE_DIR=/var/filestorage

export AXIVION_PROJECT_DIR=$(realpath ${REPO_DIR})
export AXIVION_SANDBOX_DIR=$(realpath ${SANDBOX_DIR})
export AXIVION_SOURCESERVER_GITDIR=${SERVER_FILESTORAGE_DIR}/git/${PROJECTNAME}/.git

# print variables for debugging
echo
echo "Environment variables set by $(basename $0):"
echo
echo "AXIVION_CONFIG_DIR=${AXIVION_CONFIG_DIR}"
echo "BAUHAUS_CONFIG=${BAUHAUS_CONFIG}"
echo "AXIVION_DASHBOARD_URL=${AXIVION_DASHBOARD_URL}"
echo "AXIVION_DATABASES_DIR=${AXIVION_DATABASES_DIR}"
echo "AXIVION_PROJECT_DIR=${AXIVION_PROJECT_DIR}"
echo "AXIVION_SANDBOX_DIR=${AXIVION_SANDBOX_DIR}"
echo "AXIVION_SOURCESERVER_GITDIR=${AXIVION_SOURCESERVER_GITDIR}"
echo

# ensure local filestorage exists
mkdir -p ${LOCAL_FILESTORAGE_DIR}

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    #---------------------------------------------------------------------------
    # CI build (with devnet connection)
    #---------------------------------------------------------------------------

    echo -e "Do CI build (update of dashboard server).\n"

    # mount filestorage
    sshfs filestorageuser@hc-axiviondashboard:${SERVER_FILESTORAGE_DIR} ${LOCAL_FILESTORAGE_DIR} -o idmap=user -o cache=no

else

    #---------------------------------------------------------------------------
    # Local build (with devnet connection)
    #---------------------------------------------------------------------------

    # starting local dashboard server
    dashserver start

    echo -e "Do local build (no dashboard server update).\n"

    export AXIVION_USERNAME=test
    export AXIVION_PASSWORD=cyber2020
    export AXIVION_LOCAL_BUILD=1

    for TARGET_NAME in "${!TARGETS[@]}"; do

        # check if database file already exists
        DATABASE_FILE=/home/user/.bauhaus/localbuild/projects/${PROJECTNAME}_${TARGET_NAME}.db

        if [[ ! -f "${DATABASE_FILE}" ]]; then

            # create empty database
            cidbman database create ${DATABASE_FILE}
            # install project at dashboard server
            dashserver install-project --dbfile ${DATABASE_FILE}

        fi

    done

fi


#-------------------------------------------------------------------------------
# Do analysis
#-------------------------------------------------------------------------------

export ENABLE_ANALYSIS=ON

# do "clean before" for the first build
export AXIVION_CLEAN_BEFORE=true

for TARGET_NAME in "${!TARGETS[@]}"; do

    # set project name for target
    export AXIVION_PROJECTNAME=${PROJECTNAME}_${TARGET_NAME}

    # create target arguments list and set environment variables
    read -a TARGET_ARGS <<< ${TARGETS[${TARGET_NAME}]}
    export BUILD_TARGET=${TARGET_ARGS[0]}
    export AXIVION_OUTFILE=${BUILD_DIR}/${TARGET_ARGS[1]}

    # run axivion
    axivion_ci -j

    # skip "clean before" after the first build
    export AXIVION_CLEAN_BEFORE=false

done


#-------------------------------------------------------------------------------
# Tear down workflow
#-------------------------------------------------------------------------------

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    # synchronize cached writes
    sync

    # unmount filestorage
    fusermount -u ${LOCAL_FILESTORAGE_DIR}

fi
