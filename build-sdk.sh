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
OS_SDK_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"


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

        # the build runs from within the build folder, which is created in the
        # test workspace. We have to ensure that the source path is accessible
        # from there, the most simple way to achieve this is having it as
        # absolute path
        local ABS_CMAKE_FILE=$(realpath ${CMAKE_FILE})
        mkdir -p ${BUILD_DIR}
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
function copy_files()
{
    SRC_DIR=$1
    DST_DIR=$2
    shift 2

    # rsync would do the job nicely, but unfortunately it is not available in
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
    mkdir -p ${DST_DIR}
    tar -c -C ${SRC_DIR} $@ ./ | tar -x -C ${DST_DIR}/
}


#-------------------------------------------------------------------------------
function collect_sdk_sources()
{
    local SDK_SRC_DIR=$1
    local OUT_DIR=$2
    shift 2

    print_info "collecting SDK sources from ${SDK_SRC_DIR}"

    # ToDo: create file with git infos

    # remove any existing output directory
    if [ -d ${OUT_DIR} ]; then
        rm -rf ${OUT_DIR}
    fi

    local SDK_EXCLUDES=(
        --exclude-vcs
        ### seems there is a bug in tar, the file .gitmodules is not
        ### excluded as specified. Using --exclude-vcs instead.
        #--exclude '.gitmodules'
        #--exclude '.git*'
        --exclude 'astyle_check.sh'
        --exclude './astyle_check_sdk.sh'
        --exclude './build-sdk.sh'
        --exclude './jenkinsfile-control'
        --exclude './jenkinsfile-generic'
        --exclude './publish_doc.sh'
        --exclude './sdk-pdfs'
        --exclude './sdk-sel4-camkes/tools/riscv-pk'
    )
    copy_files ${SDK_SRC_DIR} ${OUT_DIR} ${SDK_EXCLUDES[@]}

    # we make assumption about the directory structure of seos_tests now,
    # but that is acceptable for the moment
    local SDK_SRC_DEMOS_DIR=${SDK_SRC_DIR}/../src/demos
    local OUT_DEMOS_DIR=${OUT_DIR}/demos

    for SDK_DEMO_NAME in $(ls ${SDK_SRC_DEMOS_DIR}) ; do
        local SDK_EXCLUDES=(
            --exclude-vcs
            --exclude 'astyle_check.sh'
        )
        copy_files \
            ${SDK_SRC_DEMOS_DIR}/${SDK_DEMO_NAME} \
            ${OUT_DEMOS_DIR}/${SDK_DEMO_NAME}/src \
            ${SDK_EXCLUDES[@]}
    done
}


#-------------------------------------------------------------------------------
function build_sdk_demos()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2

    for SDK_DEMO_NAME in $(ls ${SDK_SRC_DIR}/demos) ; do
        print_info "Building SDK demo: ${SDK_DEMO_NAME}"

        local SDK_DEMO_BASE=${SDK_SRC_DIR}/demos/${SDK_DEMO_NAME}
        local SDK_DEMO_SRC=${SDK_DEMO_BASE}/src
        local SDK_DEMO_OUT=${BUILD_DIR}/${SDK_DEMO_NAME}

        # default values
        local TARGET=zynq7000
        local PLAT=zynq7000
        local ARCH=arm

        if [[ ${SDK_DEMO_NAME} =~ "rpi3" ]]; then
            TARGET="rpi3"
            PLAT="bcm2837"
            ARCH="arm"
        fi

        local BUILD_PARAMS=(
            ${SDK_DEMO_SRC}
            ${TARGET}
            ${SDK_DEMO_OUT}
            -D CMAKE_BUILD_TYPE=Debug
        )
        ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}

        mkdir ${SDK_DEMO_BASE}/bin
        cp ${SDK_DEMO_OUT}/images/capdl-loader-image-${ARCH}-${PLAT} \
           ${SDK_DEMO_BASE}/bin
    done
}


#-------------------------------------------------------------------------------
function build_sdk_tool()
{
    local SDK_SRC_DIR=$1
    local SDK_TOOL=$2
    local BUILD_DIR=$3

    print_info "Building SDK tool: ${SDK_TOOL} -> ${BUILD_DIR}"

    local BUILD_PARAMS=(
        ${BUILD_DIR}                # build output folder
        all                         # ninja target
        ${SDK_SRC_DIR}/${SDK_TOOL}  # folder containing CMakeList file
        # custom build params start here

        # SDK_SRC_DIR may be a relative path to the current directory, but the
        # build will change the working directory to BUILD_DIR. Thus we must
        # pass an absolute path here
        -D OS_SDK_SOURCE_PATH:STRING=$(realpath ${SDK_SRC_DIR})
    )

    cmake_check_init_and_build ${BUILD_PARAMS[@]}
}


#-------------------------------------------------------------------------------
function sdk_unit_test()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2
    shift 2

    print_info "running SDK Libs Unit Tests"

    local BUILD_PARAMS=(
        ${BUILD_DIR}/test_seos_libs       # build output folder
        cov                               # ninja target
        ${SDK_SRC_DIR}/libs/os_libs/test  # folder containing CMakeList file
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
        local TOOLS_SRC_DIR=tools/kpt
        local TOOLS_BUILD_DIR=${BUILD_DIR}/kpt

        build_sdk_tool ${SDK_SRC_DIR} ${TOOLS_SRC_DIR} ${TOOLS_BUILD_DIR}

        cp ${TOOLS_BUILD_DIR}/keystore_provisioning_tool ${OUT_DIR}/kpt
        cp -v ${SDK_SRC_DIR}/${TOOLS_SRC_DIR}/xmlParser.py ${OUT_DIR}
    )

    # build config provisioning tool
    (
        local TOOLS_SRC_DIR=tools/cpt
        local TOOLS_BUILD_DIR=${BUILD_DIR}/cpt

        build_sdk_tool ${SDK_SRC_DIR} ${TOOLS_SRC_DIR} ${TOOLS_BUILD_DIR}

        cp ${TOOLS_BUILD_DIR}/cpt ${OUT_DIR}/cpt
    )

    # build ramdisk generator tool
    (
        local TOOLS_SRC_DIR=tools/rdgen
        local TOOLS_BUILD_DIR=${BUILD_DIR}/rdgen

        build_sdk_tool ${SDK_SRC_DIR} ${TOOLS_SRC_DIR} ${TOOLS_BUILD_DIR}

        cp ${TOOLS_BUILD_DIR}/rdgen ${OUT_DIR}/rdgen
    )
}

#-------------------------------------------------------------------------------
function build_sdk_docs()
{
    local SDK_SRC_DIR=$1
    local OUT_DIR=$2

    print_info "Building SDK docs into ${OUT_DIR} from ${SDK_SRC_DIR}"

    export DOXYGEN_INPUT_DIR=${SDK_SRC_DIR}
    export DOXYGEN_OUTPUT_DIR=${OUT_DIR}
    doxygen ${SDK_SRC_DIR}/Doxyfile
}


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
PACKAGE_MODE=$1
OUT_BASE_DIR=$2
shift 2

SDK_PACKAGE_SRC=${OUT_BASE_DIR}/pkg
SDK_PACKAGE_BUILD=${OUT_BASE_DIR}/build
SDK_PACKAGE_UNIT_TEST=${OUT_BASE_DIR}/unit-tests
SDK_PACKAGE_DOC=${OUT_BASE_DIR}/pkg/doc
SDK_PACKAGE_BIN=${OUT_BASE_DIR}/pkg/bin

# for development purposes, all the steps can also run directly from the SDK
# sources. In this case don't run "collect_sdk_sources" and set SDK_PACKAGE_SRC
# to OS_SDK_DIR for all steps

if [[ "${PACKAGE_MODE}" == "all" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${OS_SDK_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}
    build_sdk_demos ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD}
    build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}

elif [[ "${PACKAGE_MODE}" == "doc" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${OS_SDK_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}

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
    collect_sdk_sources ${OS_SDK_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}

elif [[ "${PACKAGE_MODE}" == "only-sources" ]]; then
    # do not build the documentation and binaries
    collect_sdk_sources ${OS_SDK_DIR} ${SDK_PACKAGE_SRC}

else
    echo "usage: $0 <all|bin> <OUT_BASE_DIR>"
    exit 1
fi
