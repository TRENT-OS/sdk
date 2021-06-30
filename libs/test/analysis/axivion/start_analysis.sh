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

export ENABLE_ANALYSIS=ON

export AXIVION_PROJECTNAME=LibsAnalysis
export BAUHAUS_CONFIG=${AXIVION_DIR}


#-------------------------------------------------------------------------------
# Prepare workflow
#-------------------------------------------------------------------------------

ENABLE_CI_BUILD=${ENABLE_CI_BUILD:-OFF}
DEVNET_CONNECTION=${DEVNET_CONNECTION:-OFF}

# set default configuration values
export AXIVION_PROJECT_DIR=${REPO_DIR}
export AXIVION_BUILD_DIR=${BUILD_DIR}
export AXIVION_DATABASES_DIR=/home/user/filestorage
export AXIVION_DASHBOARD_URL=http://hc-axiviondashboard:9090/axivion
export AXIVION_SOURCESERVER_GITDIR=${AXIVION_DATABASES_DIR}/git/${AXIVION_PROJECTNAME}.git

# ensure databases dir exists
mkdir -p ${AXIVION_DATABASES_DIR}

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    #---------------------------------------------------------------------------
    # CI build (with devnet connection)
    #---------------------------------------------------------------------------

    echo -e "\nDo CI build (with update of dashboard server).\n"

    # mount filestorage
    sshfs filestorageuser@hc-axiviondashboard:/var/filestorage ${AXIVION_DATABASES_DIR} -o idmap=user -o cache=no

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

    # check if database file already exists
    PROJECT_DATABASE_FILE=${AXIVION_DATABASES_DIR}/${AXIVION_PROJECTNAME}.db

    if [[ ! -f "${PROJECT_DATABASE_FILE}" ]]; then

        # create empty database
        cidbman database create ${PROJECT_DATABASE_FILE}
        # install project at dashboard server
        dashserver install-project --dbfile ${PROJECT_DATABASE_FILE}

    fi

fi


#-------------------------------------------------------------------------------
# Do analysis
#-------------------------------------------------------------------------------

axivion_ci -j


#-------------------------------------------------------------------------------
# Tear down workflow
#-------------------------------------------------------------------------------

if [[ ${ENABLE_CI_BUILD} == "ON" ]]; then

    # synchronize cached writes
    sync

    # unmount filestorage
    fusermount -u ${AXIVION_DATABASES_DIR}

fi
