#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Build script
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# This script assumes it is located in the SDK root folder
OS_SDK_PATH="${SCRIPT_DIR}"

# This script assumes is exists in the directory structure of seos_tests, the
# SDK creatin CI job adapts to this layout.
DEMOS_SRC_DIR="${SCRIPT_DIR}/../src/demos"


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
    local OUT_BASE_DIR=$2
    local OUT_PKG_DIR=$3
    shift 3

    print_info "collecting SDK sources from ${SDK_SRC_DIR}"

    # remove any existing output directory
    mkdir -p ${OUT_BASE_DIR}

    # remove any existing output directory
    if [ -d ${OUT_PKG_DIR} ]; then
        rm -rf ${OUT_PKG_DIR}
    fi
    mkdir -p ${OUT_PKG_DIR}

    local VERSION_INFO_FILE=${OUT_BASE_DIR}/version.info

    # create file with git infos
    local ABS_VERSION_INFO_FILE=$(realpath ${VERSION_INFO_FILE})
    (
        cd ${SDK_SRC_DIR}
        git submodule status --recursive >${ABS_VERSION_INFO_FILE}
    )

    local SDK_EXCLUDE_REPOS=(
        sdk-pdfs
        sdk-sel4-camkes/tools/riscv-pk
        tools/kpt
    )
    for repo in ${SDK_EXCLUDE_REPOS[@]}; do
        # replace "/" by "\/" via bash magic ${repo//\//\\/}
        sed --in-place "/ ${repo//\//\\/} /d" ${VERSION_INFO_FILE}
    done

    local SDK_EXCLUDES=(
        # remove all astyle files
        astyle_check.sh
        # remove files in the sandbox root folder
        ./astyle_check_sdk.sh
        ./build-sdk.sh
        ./jenkinsfile-control
        ./jenkinsfile-generic
        ./publish_doc.sh
        ${SDK_EXCLUDE_REPOS[@]/#/./} # prefix every element with "./"
        # remove all readme files our code because they are in a bad shape,
        # the only exception is libs/os_core_api/README.md, it looks nice and
        # is used in the doxygen process. We remove it later when creating the
        # SDK package
        ./README.md
        ./components/CryptoServer/README.md
        ./components/EntropySource/README.md
        ./components/NIC_RPi/README.md
        ./components/RPI_SPI_Flash/README.md
        ./components/StorageServer/README.md
        ./components/TimeServer/README.md
        ./components/TlsServer/README.md
        ./libs/chanmux/README.md
        ./libs/chanmux_nic_driver/README.md
        ./libs/os_cert/README.md
        ./libs/os_configuration/README.md
        ./libs/os_crypto/README.md
        ./libs/os_filesystem/README.md
        ./libs/os_keystore/README.md
        ./libs/os_libs/README.md
        ./libs/os_logger/Readme.md
        ./libs/os_network_stack/3rdParty/picotcp/README.md
        ./libs/os_network_stack/3rdParty/picotcp/docs/user_manual/README.md
        ./libs/os_network_stack/3rdParty/picotcp/test/README.md
        ./libs/os_network_stack/README.md
        ./libs/os_tls/README.md
        ./scripts/README.md
        ./sdk-sel4-camkes/README.md
        ./tools/cpt/README.md
        ./tools/proxy/README.md
        ./tools/rdgen/README.md
        ./tools/rpi3_flasher/README.md
    )

    # copy files using tar and filtering. Seems there is a bug in tar, for
    # "--exclude '.gitmodules'" the file .gitmodules is not excluded. So we
    # trust in "--exclude-vcs" to do the job properly.
    copy_files_via_tar \
        ${SDK_SRC_DIR} \
        ${OUT_PKG_DIR} \
        --exclude-vcs \
        ${SDK_EXCLUDES[@]/#/--exclude } # prefix all with "--exclude "

    # put a version.info into the SDK package for the seL4/CAmkES repos
    #sed "/ sdk-sel4-camkes\//!d" ${VERSION_INFO_FILE} > ${OUT_PKG_DIR}/sdk-sel4-camkes/version.info
}


#-------------------------------------------------------------------------------
function collect_sdk_demos()
{
    local DEMOS_DIR=$1
    local SDK_DEMOS_DIR=$2
    shift 2

    for SDK_DEMO_NAME in $(ls ${DEMOS_DIR}) ; do

        local DEMO_SRC_DIR=${DEMOS_DIR}/${SDK_DEMO_NAME}

        print_info "collecting demo sources from ${DEMO_SRC_DIR}"

        local DEMO_EXCLUDES=(
            --exclude-vcs
            --exclude 'astyle_check.sh'
            --exclude './README.md'
        )

        copy_files_via_tar \
            ${DEMO_SRC_DIR} \
            ${SDK_DEMOS_DIR}/${SDK_DEMO_NAME}/src \
            ${DEMO_EXCLUDES[@]}
    done
}


#-------------------------------------------------------------------------------
function build_sdk_demos()
{
    local SDK_SRC_DIR=$1
    local SDK_DEMOS_DIR=$2
    local BUILD_DIR=$3
    shift 3

    print_info "Building SDK demos"

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

    if [ ! -d ${SDK_DEMOS_DIR} ]; then
        echo "missing SDK demo folder, did you run the collect step?"
        exit 1
    fi

    # build RPi3 flasher using a sample file from the IoT demo
    print_info "Building SDK tool: rpi3_flasher"

    local FLASHER_SRC=${SDK_SRC_DIR}/tools/rpi3_flasher
    local FLASHER_SRC_TEST=${BUILD_DIR}/rpi3_flasher_src_test

    # pick file no from collected sandbox/demo sources, but from the original
    # repo sources
    local FLASHER_SRC_DATA=${DEMOS_SRC_DIR}/demo_iot_app_rpi3/flash.c
    if [ ! -w ${FLASHER_SRC_DATA} ]; then
        echo "missing ${FLASHER_SRC_DATA}"
        exit 1
    fi
    copy_files_via_tar ${FLASHER_SRC} ${FLASHER_SRC_TEST} --exclude-vcs
    cp ${FLASHER_SRC_DATA} ${FLASHER_SRC_TEST}/

    local BUILD_PARAMS=(
        ${FLASHER_SRC_TEST}
        rpi3
        ${BUILD_DIR}/rpi3_flasher_test
        -D CMAKE_BUILD_TYPE=Debug
    )
    ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}


    local TARGETS=(
        zynq7000
        rpi3
        # imx6
        # migv
    )

    #
    #                      | zynq7000 | rpi3 | imx6 | migv | ...
    # ---------------------+----------+------+------+------+-----
    #  demo_hello_world    | yes      | yes  | yes  | yes  |
    #  demo_iot_app        | yes      | no   | no   | no   |
    #  demo_iot_app_rpi3   | no       | yes  | no   | no   |
    #  demo_raspi_ethernet | no       | yes  | no   | no   |
    #
    declare -A TARGET_RESTRICTIONS=(
        [demo_iot_app]=zynq7000
        [demo_iot_app_rpi3]=rpi3
        [demo_raspi_ethernet]=rpi3
    )

    for SDK_DEMO_NAME in $(ls ${SDK_DEMOS_DIR}) ; do

        local CUR_TARGETS=(
            ${TARGET_RESTRICTIONS[${SDK_DEMO_NAME}]:-${TARGETS[@]}}
        )

        for TARGET in ${CUR_TARGETS[@]}; do
            print_info "Building SDK demo: ${SDK_DEMO_NAME} for ${TARGET}"

            local SDK_DEMO_OUT=${BUILD_DIR}/${SDK_DEMO_NAME}-${TARGET}

            local BUILD_PARAMS=(
                ${SDK_DEMOS_DIR}/${SDK_DEMO_NAME}/src
                ${TARGET}
                ${SDK_DEMO_OUT}
                -D CMAKE_BUILD_TYPE=Debug
            )
            ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}

            # we just build the demos to check that there is no error, but we
            # don't release prebuilt images. If we are here, we've created the
            # SDK package alewady anyway, so we can't simply copy the images.
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

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

    local BUILD_PARAMS=(
        ${BUILD_DIR}                # build output folder
        all                         # ninja target
        ${SDK_SRC_DIR}/${SDK_TOOL}  # folder containing CMakeList file
        # custom build params start here

        # SDK_SRC_DIR may be a relative path to the current directory, but the
        # build will change the working directory to BUILD_DIR. Thus we must
        # pass an absolute path here
        -D OS_SDK_PATH:PATH=$(realpath ${SDK_SRC_DIR})
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

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

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

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

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

    print_info "Building SDK docs into ${OUT_DIR} from ${SDK_SRC_DIR}"

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

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
    (
        export DOXYGEN_OUTPUT_DIR=$(realpath ${OUT_DIR})
        cd ${SDK_SRC_DIR}
        export DOXYGEN_INPUT_DIR=libs/os_core_api
        doxygen Doxyfile
    )

    # collect all the PDFs from the sandbox directory
    local SDK_PDF_DIR=${OS_SDK_PATH}/sdk-pdfs
    local OUT_DIR_PDF=${OUT_DIR}/pdf
    echo "Collecting PDF documentation in ${OUT_DIR_PDF}/..."

    PDF_FILES=(
        TRENTOS-M_GettingStarted_SDK_V1.0.pdf
        TRENTOS-M_Handbook_SDK_V1.0.pdf
        TRENTOS-M_ReleaseNotes_SDK_V1.0.pdf
    )

    for PDF_FILE in ${PDF_FILES[@]}; do
        cp -a ${SDK_PDF_DIR}/${PDF_FILE} ${OUT_DIR_PDF}
    done

    cp -a ${SDK_PDF_DIR}/3rd_party_pdf/ ${OUT_DIR_PDF}/3rd_party
}


#-------------------------------------------------------------------------------
function package_sdk()
{
    local SDK_SRC_DIR=$1
    shift 1

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        exit 1
    fi

    local SDK_PACKAGE_BZ2=sdk-package.bz2
    print_info "Packaging SDK to ${SDK_PACKAGE_BZ2}"

    du -sh ${SDK_SRC_DIR}

    local SDK_PACKAGE_EXCLUDES=(
        # remove prepare_test.sh from demos
        prepare_test.sh
        # remove readme that we needed for doxygen
        ./libs/os_core_api/README.md
        # remove all doxygen files from our modules
        ./Doxyfile
        ./libs/chanmux/Doxyfile
        ./libs/chanmux_nic_driver/Doxyfile
        ./libs/os_cert/Doxyfile
        ./libs/os_configuration/Doxyfile
        ./libs/os_core_api/Doxyfile
        ./libs/os_crypto/Doxyfile
        ./libs/os_filesystem/Doxyfile
        ./libs/os_keystore/Doxyfile
        ./libs/os_libs/Doxyfile
        ./libs/os_logger/Doxyfile
        ./libs/os_network_stack/Doxyfile
        ./libs/os_tls/Doxyfile
    )

    # prefix everything in SDK_EXCLUDE_ELEMENTS with "--exclude "
    tar \
        -cjf ${SDK_PACKAGE_BZ2} \
        -C ${SDK_SRC_DIR} \
        ${SDK_PACKAGE_EXCLUDES[@]/#/--exclude } \
        .

    du -sh ${SDK_PACKAGE_BZ2}
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
PACKAGE_MODE=$1
OUT_BASE_DIR=$2
shift 2

# for development purposes, all the steps can also run directly from the SDK
# sources. In this case don't run "collect_sdk_sources" and set SDK_PACKAGE_SRC
# to OS_SDK_PATH for all steps


SDK_BUILD=${OUT_BASE_DIR}/build
SDK_UNIT_TEST=${OUT_BASE_DIR}/unit-tests
SDK_PACKAGE_SRC=${OUT_BASE_DIR}/pkg
SDK_PACKAGE_DOC=${SDK_PACKAGE_SRC}/doc
SDK_PACKAGE_BIN=${SDK_PACKAGE_SRC}/bin
SDK_PACKAGE_DEMOS=${SDK_PACKAGE_SRC}/demos


#-------------------------------------------------------------------------------
function do_sdk_step()
{
    local STEP=$1

    case "${STEP}" in
        collect_sdk_sources)
            ${STEP} ${OS_SDK_PATH} ${OUT_BASE_DIR} ${SDK_PACKAGE_SRC}
            ;;

        sdk_unit_test)
            ${STEP} ${SDK_PACKAGE_SRC} ${SDK_UNIT_TEST}
            ;;

        build_sdk_docs)
            ${STEP} ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}
            ;;

        build_sdk_tools)
            ${STEP} ${SDK_PACKAGE_SRC} ${SDK_BUILD} ${SDK_PACKAGE_BIN}
            ;;

        package_sdk)
            ${STEP} ${SDK_PACKAGE_SRC}
            ;;

        collect_sdk_demos)
            ${STEP} ${DEMOS_SRC_DIR} ${SDK_PACKAGE_DEMOS}
            ;;

        build_sdk_demos)
            ${STEP} ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DEMOS} ${SDK_BUILD}
            ;;

        *)
            echo "invalid STEP: ${STEP}"
            exit 1
            ;;
    esac
}

#-------------------------------------------------------------------------------
function do_sdk_multi_step()
{
    local MULTISTEP=$1

    case "${MULTISTEP}" in
        package)
            # create SDK package including demos
            do_sdk_step collect_sdk_sources
            do_sdk_step build_sdk_tools
            do_sdk_step collect_sdk_demos
            do_sdk_step build_sdk_docs
            do_sdk_step package_sdk
            ;;

        *)
            echo "invalid MULTISTEP: ${MULTISTEP}"
            exit 1
            ;;
    esac
}


if [[ "${PACKAGE_MODE}" == "all" ]]; then
    do_sdk_multi_step package
    # unit test are not part of the SDK package
    do_sdk_step sdk_unit_test
    # demo builds are not part of the SDK package, this is just a test.
    do_sdk_step build_sdk_demos

elif [[ "${PACKAGE_MODE}" == "build-bin" ]]; then
    # collect sources and build the SDK binaries
    do_sdk_step collect_sdk_sources
    do_sdk_step build_sdk_tools

elif [[ "${PACKAGE_MODE}" == "build-demos" ]]; then
    # build demos against a created package, used by CI
    do_sdk_step build_sdk_demos

elif [[ "${PACKAGE_MODE}" == "demos" ]]; then
    # create SDK snapshot, collect demos and build them
    do_sdk_step collect_sdk_sources
    do_sdk_step collect_sdk_demos
    do_sdk_step build_sdk_demos

elif [[ "${PACKAGE_MODE}" == "doc" ]]; then
    # create SDK snapshot and build documentation from it
    do_sdk_step collect_sdk_sources
    # note that there are no demos collected here
    do_sdk_step build_sdk_docs

elif [[ "${PACKAGE_MODE}" == "only-sources" ]]; then
    # create SDK snapshot, no docs, tool or demos
    do_sdk_step collect_sdk_sources

elif [[ "${PACKAGE_MODE}" == "package" ]]; then
    # create an SDK package, used by CI
    do_sdk_multi_step package

elif [[ "${PACKAGE_MODE}" == "unit-tests" ]]; then
    # run units test on a created package, used by CI
    do_sdk_step sdk_unit_test

else
    echo "usage: $0 <mode> <OUT_BASE_DIR>"
    echo "  where mode is: all, build-bin, build-demos, demos, doc, only-sources, package, unit-tests"
    exit 1
fi
