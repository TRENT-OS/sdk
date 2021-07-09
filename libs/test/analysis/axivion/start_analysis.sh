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

export PROJECTNAME=LibsAnalysis

# The TARGETS variable defines the CMake build targets and outfiles for multiple
# analysis projects. Usually the targets are components of a TRENTOS system. The
# name of the analysis project will be "PROJECTNAME_TargetName".
declare -A TARGETS=(
    # [TargetName]="<BuildTarget> <OutfileInBuildDir>"
    [Main]="analysis test/analysis/libanalysis.so"
)


#-------------------------------------------------------------------------------
# Prepare workflow
#-------------------------------------------------------------------------------

ENABLE_CI_BUILD=${ENABLE_CI_BUILD:-OFF}
DEVNET_CONNECTION=${DEVNET_CONNECTION:-OFF}

# set default configuration values
export BAUHAUS_CONFIG=${AXIVION_DIR}
export AXIVION_PROJECT_DIR=${REPO_DIR}
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
