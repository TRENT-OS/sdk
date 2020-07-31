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
function copy_files_via_tar()
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
    local DEMO_SRC_DIR=$2
    local OUT_DIR=$3
    shift 3

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
        #--exclude './Doxyfile' # build_sdk_docs() still needs this file
        --exclude './jenkinsfile-control'
        --exclude './jenkinsfile-generic'
        --exclude './publish_doc.sh'
        --exclude './sdk-pdfs'
        --exclude './sdk-sel4-camkes/tools/riscv-pk'
        --exclude './tools/kpt'
    )
    copy_files_via_tar ${SDK_SRC_DIR} ${OUT_DIR} ${SDK_EXCLUDES[@]}

    # copy demos
    local OUT_DEMOS_DIR=${OUT_DIR}/demos
    for SDK_DEMO_NAME in $(ls ${DEMO_SRC_DIR}) ; do
        local DEMO_EXCLUDES=(
            --exclude-vcs
            --exclude 'astyle_check.sh'
        )
        copy_files_via_tar \
            ${DEMO_SRC_DIR}/${SDK_DEMO_NAME} \
            ${OUT_DEMOS_DIR}/${SDK_DEMO_NAME}/src \
            ${DEMO_EXCLUDES[@]}
    done
}


#-------------------------------------------------------------------------------
function build_sdk_demos()
{
    local SDK_SRC_DIR=$1
    local BUILD_DIR=$2

    local TARGETS=(
        zynq7000
        rpi3
        # imx6
        # migv
    )

    #
    #                     | zynq7000 | rpi3 | imx6 | migv | ...
    # --------------------+----------+------+------+------+-----
    #  demo_hello_world   | yes      | yes  | yes  | yes  |
    #  demo_iot_app       | yes      | no   | no   | no   |
    #  demo_iot_app_rpi3  | no       | yes  | no   | no   |
    #
    declare -A TARGET_RESTRICTIONS=(
        [demo_iot_app]=zynq7000
        [demo_iot_app_rpi3]=rpi3
    )

    for SDK_DEMO_NAME in $(ls ${SDK_SRC_DIR}/demos); do

        local CUR_TARGETS=(
            ${TARGET_RESTRICTIONS[${SDK_DEMO_NAME}]:-${TARGETS[@]}}
        )

        for TARGET in ${CUR_TARGETS[@]}; do
            print_info "Building SDK demo: ${SDK_DEMO_NAME} for ${TARGET}"

            local SDK_DEMO_BASE=${SDK_SRC_DIR}/demos/${SDK_DEMO_NAME}
            local SDK_DEMO_SRC=${SDK_DEMO_BASE}/src
            local SDK_DEMO_OUT=${BUILD_DIR}/${SDK_DEMO_NAME}-${TARGET}

            local BUILD_PARAMS=(
                ${SDK_DEMO_SRC}
                ${TARGET}
                ${SDK_DEMO_OUT}
                -D CMAKE_BUILD_TYPE=Debug
            )
            ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}

            # we just build the demos to check that there is no error, but we
            # don't release prebuilt images
            #
            # mkdir -p ${SDK_DEMO_BASE}/bin
            # cp ${SDK_DEMO_OUT}/images/os_image.bin \
            #    ${SDK_DEMO_BASE}/bin/os_image-${TARGET}.bin
        done
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
    local SDK_PDF_DIR=${OS_SDK_DIR}/sdk-pdfs

    print_info "Building SDK docs into ${OUT_DIR} from ${SDK_SRC_DIR}"

    # clear folder where we collect docs
    if [[ -e ${OUT_DIR} ]]; then
        echo "removing attic API documentation collection folder"
        rm -rf ${OUT_DIR}
    fi

    mkdir -p ${OUT_DIR}/pdf

    # TODO We only create the documentation of the os_core_api.
    #
    # It is planned to do a documentation of the entire SDK once it is well
    # documented.
    export DOXYGEN_INPUT_DIR=${SDK_SRC_DIR}/libs/os_core_api
    export DOXYGEN_OUTPUT_DIR=${OUT_DIR}
    doxygen ${SDK_SRC_DIR}/Doxyfile

    # collect all the pdfs
    echo "Collecting PDF documentation in ${OUT_DIR}/pdf..."
    local ABS_OUT_DIR_PDF=$(realpath ${OUT_DIR}/pdf)

    cp -a ${SDK_PDF_DIR}/*.pdf ${ABS_OUT_DIR_PDF}
    (
        # substitute the paths to the doxygen documentation

        local SUBS_DIR=$(realpath ${OUT_DIR}/html)

        # HOST_DIR is an environment variable that is defined in case of
        # usage of the script with the provided docker build wrapper
        # "seos_build_env.sh" the wrapper binds the folder /host inside the
        # container to the current working directory from where it is called.
        # This information is needed in order to provide correct links
        # to the doxygen htmls inside the PDFs: /host must be replaced by
        # $HOST_DIR
        if [ ! -z "${HOST_DIR-}" ]; then
            SUBS_DIR=$(echo ${SUBS_DIR} | sed 's/\/host//g')
            SUBS_DIR=${HOST_DIR}/${SUBS_DIR}
        fi
        cd ${ABS_OUT_DIR_PDF}
        ${SDK_PDF_DIR}/substitute_doxygen_path.sh ${SUBS_DIR}
    )
}


#-------------------------------------------------------------------------------
function package_sdk()
{
    local SDK_SRC_DIR=$1
    shift 1

    local SDK_PACKAGE_BZ2=sdk-package.bz2
    print_info "Packaging SDK to ${SDK_PACKAGE_BZ2}"

    du -sh ${SDK_PACKAGE_SRC}

    local SDK_PACKAGE_EXCLUDES=(
        --exclude 'prepare_test.sh'
        # --exclude './Doxyfile'
    )

    tar -cjf ${SDK_PACKAGE_BZ2} ${SDK_PACKAGE_EXCLUDES[@]} \
        -C ${SDK_PACKAGE_SRC} .

    du -sh ${SDK_PACKAGE_BZ2}
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
PACKAGE_MODE=$1
OUT_BASE_DIR=$2
shift 2


SDK_PACKAGE_BUILD=${OUT_BASE_DIR}/build
SDK_PACKAGE_UNIT_TEST=${OUT_BASE_DIR}/unit-tests
SDK_PACKAGE_SRC=${OUT_BASE_DIR}/pkg
SDK_PACKAGE_DOC=${OUT_BASE_DIR}/pkg/doc
SDK_PACKAGE_BIN=${OUT_BASE_DIR}/pkg/bin

# we make an assumption about the directory structure of seos_tests here, which
# acceptable for the moment. CI adapts to this layout.
DEMOS_SRC_DIR=${OS_SDK_DIR}/../src/demos


# for development purposes, all the steps can also run directly from the SDK
# sources. In this case don't run "collect_sdk_sources" and set SDK_PACKAGE_SRC
# to OS_SDK_DIR for all steps

if [[ "${PACKAGE_MODE}" == "all" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${OS_SDK_DIR} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}
    build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}
    build_sdk_demos ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD}
    package_sdk ${SDK_PACKAGE_SRC}

elif [[ "${PACKAGE_MODE}" == "demos" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${OS_SDK_DIR} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_demos ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD}

elif [[ "${PACKAGE_MODE}" == "doc" ]]; then
    # create SDK snapshot from repos sources and build SDK from snapshot
    collect_sdk_sources ${OS_SDK_DIR} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}

elif [[ "${PACKAGE_MODE}" == "unit-tests" ]]; then
    # unit testing is a separate step, because the build docker container that
    # is used to collect the files and creates the SDK package not have the
    # unit test tool installed.
    if [ ! -d ${SDK_PACKAGE_SRC} ]; then
        echo "please build an SDK package first"
        exit 1
    fi
    sdk_unit_test ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_UNIT_TEST}

elif [[ "${PACKAGE_MODE}" == "build-bin" ]]; then
    # do not build the documentation
    collect_sdk_sources ${OS_SDK_DIR} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_SRC}
    build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_BUILD} ${SDK_PACKAGE_BIN}

elif [[ "${PACKAGE_MODE}" == "only-sources" ]]; then
    # do not build the documentation and binaries
    collect_sdk_sources ${OS_SDK_DIR} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_SRC}

else
    echo "usage: $0 <mode> <OUT_BASE_DIR>"
    echo "  where mode is: all, build-bin, demos, doc, only-sources, unit-tests"
    exit 1
fi
