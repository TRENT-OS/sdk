#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Build script
#
# Copyright (C) 2019, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

BUILD_SCRIPT_DIR=$(cd `dirname $0` && pwd)

#-------------------------------------------------------------------------------
function run_build_doc()
{
    echo ""
    echo "##"
    echo "## building: SEOS API documentation"
    echo "##"

    # build dir will be a subdirectory of the current directory, where this
    # script is invoked in. We make this a global variable, so all following
    # steps can find the build directory easily
    BUILD_DIR=$(pwd)/build-DOC

    # check if cmake init has failed previously
    if [[ -e ${BUILD_DIR} ]] && [[ ! -e ${BUILD_DIR}/rules.ninja ]]; then
        echo "deleting broken build folder and re-initialize it"
        rm -rf ${BUILD_DIR}
    fi

    if [[ ! -e ${BUILD_DIR} ]]; then
        # use subshell to configure the build
        (
            mkdir -p ${BUILD_DIR}
            cd ${BUILD_DIR}

            # configure build
            cmake -DSEOS_SANDBOX_DOC=ON $@ -G Ninja ${BUILD_SCRIPT_DIR}
        )
    fi

    # build in subshell
    (
        cd ${BUILD_DIR}
        ninja seos_sandbox_doc

        # collect SEOS API documentation
        local DOC_MODULES=$(find . -name html -type d -printf "%P\n")

        # folder where we collect things
        local SEOS_DOC_OUTPUT=SEOS-API_doc-html
        if [[ -e ${SEOS_DOC_OUTPUT} ]]; then
            echo "removing attic documentation collection folder"
            rm -rf ${SEOS_DOC_OUTPUT}
        fi
        mkdir ${SEOS_DOC_OUTPUT}
        echo "collecting HTML documentation in ${SEOS_DOC_OUTPUT}..."
        for module in ${DOC_MODULES[@]}; do
            local TARGET_FOLDER=$(basename $(dirname ${module}))
            echo "  ${TARGET_FOLDER} <- ${module}"
            cp -ar ${module} ${SEOS_DOC_OUTPUT}/${TARGET_FOLDER}
        done
    )
}

#-------------------------------------------------------------------------------

if [[ "${1:-}" == "doc" ]]; then
    shift
    run_build_doc $@

else

    echo "nothing else than documentation can be built, re-run './build.sh doc'"

fi
