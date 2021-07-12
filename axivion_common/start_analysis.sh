#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# Starts the static code analysis with the Axivion Suite for the given Axivion
# configuration directory of an analysis project.
#
# Usage: start_analysis.sh axivion_config_dir [repo_dir]
#     axivion_config_dir  Project specific axivion configuration directory.
#     repo_dir            Root repo folder containing '.git' (default: cwd).
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Get arguments / show usage information
#-------------------------------------------------------------------------------

AXIVION_CONFIG_DIR=${1:-}
REPO_DIR=${2:-$(pwd)}

USAGE_INFO="Usage: $(basename $0) axivion_config_dir [repo_dir]
    axivion_config_dir  Project specific axivion configuration directory.
    repo_dir            Root repo folder containing '.git' (default: cwd)."

if [ "$#" -lt 1 ]; then
    echo "${USAGE_INFO}"
    exit 0
fi

if [ ! -f "${AXIVION_CONFIG_DIR}/set_axivion_config" ]; then
    echo "Invalid argument: AXIVION_CONFIG_DIR=${AXIVION_CONFIG_DIR}"
    echo
    echo "${USAGE_INFO}"
    exit 0
fi

if [ ! -d "${REPO_DIR}/.git" ]; then
    echo "Invalid argument: REPO_DIR=${REPO_DIR}"
    echo
    echo "${USAGE_INFO}"
    exit 0
fi


#-------------------------------------------------------------------------------
# Prepare analysis
#-------------------------------------------------------------------------------

source ${AXIVION_CONFIG_DIR}/set_axivion_config


#-------------------------------------------------------------------------------
# Prepare workflow
#-------------------------------------------------------------------------------

ENABLE_CI_BUILD=${ENABLE_CI_BUILD:-OFF}
DEVNET_CONNECTION=${DEVNET_CONNECTION:-OFF}

# set default configuration values
export BAUHAUS_CONFIG=$(realpath ${AXIVION_CONFIG_DIR})
export AXIVION_PROJECT_DIR=$(realpath ${REPO_DIR})
export AXIVION_DASHBOARD_URL=http://hc-axiviondashboard:9090/axivion

LOCAL_FILESTORAGE_DIR=/home/user/filestorage
export AXIVION_DATABASES_DIR=${LOCAL_FILESTORAGE_DIR}
SERVER_FILESTORAGE_DIR=/var/filestorage
export AXIVION_SOURCESERVER_GITDIR=${SERVER_FILESTORAGE_DIR}/git/${PROJECTNAME}.git

# ensure local filestorage exists
mkdir -p ${LOCAL_FILESTORAGE_DIR}

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    #---------------------------------------------------------------------------
    # CI build (with devnet connection)
    #---------------------------------------------------------------------------

    echo -e "\nDo CI build (with update of dashboard server).\n"

    # mount filestorage
    sshfs filestorageuser@hc-axiviondashboard:${SERVER_FILESTORAGE_DIR} ${LOCAL_FILESTORAGE_DIR} -o idmap=user -o cache=no

else

    #---------------------------------------------------------------------------
    # Local CI build (with or without devnet connection)
    #---------------------------------------------------------------------------

    # starting local dashboard server
    dashserver start

    echo -e "\nDo local CI build (without update of dashboard server).\n"

    # use local dashboard and repo
    export AXIVION_DASHBOARD_URL=http://localhost:9090/axivion
    export AXIVION_SOURCESERVER_GITDIR=${AXIVION_PROJECT_DIR}/.git

    for TARGET_NAME in "${!TARGETS[@]}"; do

        # check if database file already exists
        DATABASE_FILE=${LOCAL_FILESTORAGE_DIR}/${PROJECTNAME}_${TARGET_NAME}.db

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
