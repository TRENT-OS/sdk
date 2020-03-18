#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Build script
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

# This script assumes it is located in the SDK root folder and should be invoked
# from the desired build output directory.
SEOS_SDK_DIR=$(cd `dirname $0` && pwd)

#-------------------------------------------------------------------------------
function print_info()
{
    local INFO=$1

    echo -e "\n## ${INFO}\n"
}


#-------------------------------------------------------------------------------
function cmake_check_init_and_build()
{
    local BUILD_DIR=$1
    local NINJA_TARGET=$2
    local CMAKE_FILE=$3
    # all other params are passed on
    shift 3

    # check if CMake init has failed previously
    if [[ -e ${BUILD_DIR} ]] && [[ ! -e ${BUILD_DIR}/rules.ninja ]]; then
        echo "deleting broken build folder and re-initialize it"
        rm -rf ${BUILD_DIR}
    fi

    # initilaize CMake if no build folder exists
    if [[ ! -e ${BUILD_DIR} ]]; then
        mkdir -p ${BUILD_DIR}
        local ABS_CMAKE_FILE=$(realpath ${CMAKE_FILE})
        # use subshell to configure the build
        (
            cd ${BUILD_DIR}
            cmake $@ -G Ninja ${ABS_CMAKE_FILE}
        )
    fi

    # build in subshell
    (
        cd ${BUILD_DIR}
        ninja ${NINJA_TARGET}
    )
}


#-------------------------------------------------------------------------------
function collect_sdk_sources()
{
    local SDK_SRC_DIR=$1
    local OUT_DIR=$2
    shift 2

    print_info "collecting SDK sources from ${SDK_SRC_DIR}"

    # ToDo: create file with git infos

    # remove any existing otuput directory
    if [ -d ${OUT_DIR} ]; then
        rm -rf ${OUT_DIR}
    fi
    mkdir -p ${OUT_DIR}

    # rsyn would do the job nicely, but unfortunately it is not available in
    # some environments
    #
    #   rsync -a \
    #       --exclude='.git' \
    #       --exclude='.gitmodules' \
    #       --exclude='.gitignore' \
    #       --exclude 'astyle_check.sh' \
    #       ${SDK_SRC_DIR}/ \
    #       ${OUT_DIR}/
    #
    # so we (ab)use tar for this, which is faster than cp. And as side effect,
    # from this solution we could easily derive a way to get everything into
    # one archive - if we ever need this.
    local ABS_OUT_DIR=$(realpath ${OUT_DIR})
    (
        cd ${SDK_SRC_DIR}
        tar -c --exclude '.git*' --exclude 'astyle_check.sh' ./ | tar -x -C ${ABS_OUT_DIR}/
    )
}


#-------------------------------------------------------------------------------
function build_sdk_tool()
{
    local SDK_SRC_DIR=$1
    local SDK_TOOL=$2
    local BUILD_DIR=$3

    print_info "Building SDK tool: ${SDK_TOOL} -> ${BUILD_DIR}"

    local BUILD_PARAMS=(
        ${BUILD_DIR}
        all                         # ninja target
        ${SDK_SRC_DIR}/${SDK_TOOL}  # CMakeList file
        # params start here

        # SDK_SRC_DIR may be a relative path to the current directory, but the
        # build will change the working directory to BUILD_DIR. Thus we must
        # pass an absolute path here
        -D SANDBOX_SOURCE_PATH:STRING=$(realpath ${SDK_SRC_DIR})
    )

    cmake_check_init_and_build ${BUILD_PARAMS[@]}
}


#-------------------------------------------------------------------------------
function sdk_unit_test()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2
    shift 2

    print_info "running SEOS Libs Unit Tests"

    local BUILD_PARAMS=(
        ${BUILD_DIR}/test_seos_libs
        cov # ninja target
        ${SDK_SRC_DIR}/projects/libs/seos_libs/test  # CMakeList file
    )

    cmake_check_init_and_build ${BUILD_PARAMS[@]}
}


#-------------------------------------------------------------------------------
function build_sdk_tools()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2
    local OUT_DIR=$3
    shift 3

    print_info "building SDK tools into ${OUT_DIR} from ${SDK_SRC_DIR}"

    # remove any existing output directory
    if [ -d ${OUT_DIR} ]; then
        rm -rf ${OUT_DIR}
    fi
    mkdir -p ${OUT_DIR}

    # build proxy
    (
        local TOOLS_SRC_DIR=tools/proxy
        local TOOLS_BUILD_DIR=${BUILD_DIR}/proxy

        build_sdk_tool ${SDK_SRC_DIR} ${TOOLS_SRC_DIR} ${TOOLS_BUILD_DIR}

        cp ${TOOLS_BUILD_DIR}/proxy_app ${OUT_DIR}
    )

    # build keystore provisioning tool
    (
        local TOOLS_SRC_DIR=tools/keystore_provisioning_tool
        local TOOLS_BUILD_DIR=${BUILD_DIR}/kspt

        build_sdk_tool ${SDK_SRC_DIR} ${TOOLS_SRC_DIR} ${TOOLS_BUILD_DIR}

        cp ${TOOLS_BUILD_DIR}/keystore_provisioning_tool ${OUT_DIR}/kspt
        cp -v ${SDK_SRC_DIR}/${TOOLS_SRC_DIR}/xmlParser.py ${OUT_DIR}
    )
}

#-------------------------------------------------------------------------------
function build_sdk_docs()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2/docs
    local OUT_DIR=$3
    shift 3

    print_info "building SDK docs into ${OUT_DIR} from ${SDK_SRC_DIR}"

    local BUILD_PARAMS=(
        ${BUILD_DIR}
        seos_sandbox_doc    # ninja target
        ${SDK_SRC_DIR}      # CMakeList file
        # params start here
        -D SEOS_SANDBOX_DOC=ON
    )

    cmake_check_init_and_build ${BUILD_PARAMS[@]}

    # collect SEOS API documentation
    echo "collecting HTML documentation in ${OUT_DIR}..."

    # clear folder where we collect docs
    if [[ -e ${OUT_DIR} ]]; then
        echo "removing attic SEOS API documentation collection folder"
        rm -rf ${OUT_DIR}
    fi
    mkdir -p ${OUT_DIR}

    # we change the current directory to execute "find", because this works
    # best when processing the results
    local ABS_OUT_DIR=$(realpath ${OUT_DIR})
    (
        cd ${BUILD_DIR}
        local DOC_MODULES=$(find . -name html -type d -printf "%P\n")

        for module in ${DOC_MODULES[@]}; do
            local TARGET_FOLDER=$(basename $(dirname ${module}))
            echo "  ${TARGET_FOLDER} <- ${module}"
            cp -ar ${module} ${ABS_OUT_DIR}/${TARGET_FOLDER}
        done
        cp -ar seos-api-index.html ${ABS_OUT_DIR}/index.html
    )
}


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
PACKAGE_MODE=$1
OUT_BASE_DIR=$2
shift 2

SDK_PACKAGE_SRC=${OUT_BASE_DIR}/src
SDK_PACKAGE_BUILD=${OUT_BASE_DIR}/build
SDK_PACKAGE_UNIT_TEST=${OUT_BASE_DIR}/unit-tests
SDK_PACKAGE_DOC=${OUT_BASE_DIR}/doc
SDK_PACKAGE_BIN=${OUT_BASE_DIR}/bin

# for development purposes, all the steps can also run directly from the SDK
# sources. In this case don't run "collect_sdk_sources" and set SDK_PACKAGE_SRC
# to SEOS_SDK_DIR for all steps

if [[ "${PACKAGE_MODE}" == "all" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${SEOS_SDK_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}
    build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_DOC}

elif [[ "${PACKAGE_MODE}" == "unit-tests" ]]; then
    # unit testing are a completely separate step, because the usualy build
    # docker container does not have the unit test tool installed. So we need
    # to make unit testing available as separate step that can run after an SDK
    # package build.
    if [ ! -d ${SDK_PACKAGE_SRC} ]; then
        echo "please build an SDK package first"
        exit 1
    fi
    sdk_unit_test ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_UNIT_TEST}

elif [[ "${PACKAGE_MODE}" == "build-bin" ]]; then
    # do not build the documentation
    collect_sdk_sources ${SEOS_SDK_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}

elif [[ "${PACKAGE_MODE}" == "only-sources" ]]; then
    # do not build the documentation and binaries
    collect_sdk_sources ${SEOS_SDK_DIR} ${SDK_PACKAGE_SRC}

else
    echo "usage: $0 <all|bin> <OUT_BASE_DIR>"
    exit 1
fi
