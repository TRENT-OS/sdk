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
    local BUILD_TARGET=$2
    local SRC_DIR=$3
    # all other params are use to initialize the CMake build
    shift 3

    # Wipe the build folder if it does not contain a valid setup. CMake 3.18
    # changed the location of rules.ninja to CMakeFiles/rules.ninja.
    if [[ -d ${BUILD_DIR} \
          && ( ! -e ${BUILD_DIR}/CMakeCache.txt \
               || ( ! -e ${BUILD_DIR}/rules.ninja \
                    && ! -e ${BUILD_DIR}/CMakeFiles/rules.ninja) ) ]]; then
        echo "deleting broken build folder ${BUILD_DIR}"
        rm -rf ${BUILD_DIR}
    fi

    # initialize CMake if no build folder exists
    if [[ ! -e ${BUILD_DIR} ]]; then
        echo "configure build in ${BUILD_DIR}"
        cmake $@ -G Ninja -S ${SRC_DIR} -B ${BUILD_DIR}
    fi

    cmake --build ${BUILD_DIR} --target ${BUILD_TARGET}
}


#-------------------------------------------------------------------------------
function copy_files_via_tar()
{
    local SRC_DIR=$1
    local DST_DIR=$2
    shift 2

    # rsync would do the job nicely, but unfortunately it is not available in
    # some environments
    #
    #   rsync -a \
    #       --exclude='.git' \
    #       --exclude='.gitmodules' \
    #       --exclude='.gitignore' \
    #       --exclude 'astyle_prepare_submodule.sh' \
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
# i.MX6 platforms' resources require special handling as some files are common
# in the source repository, but we don't want to expose this in the final
# packages.
function copy_imx6_resources
{
    local SRC_DIR=$1
    local DST_DIR=$2
    shift 2

    print_info \
      "Copying Nitrogen SoloX resources from ${SRC_DIR} to ${DST_DIR}"

    copy_files_via_tar \
        ${SRC_DIR}/nitrogen6sx \
        ${DST_DIR}/nitrogen6sx_sd_card

    copy_files_via_tar \
        ${SRC_DIR}/common \
        ${DST_DIR}/nitrogen6sx_sd_card

    print_info \
      "Copying Sabre Lite resources from ${SRC_DIR} to ${DST_DIR}"

    copy_files_via_tar \
        ${SRC_DIR}/sabre \
        ${DST_DIR}/sabre_sd_card

    copy_files_via_tar \
        ${SRC_DIR}/common \
        ${DST_DIR}/sabre_sd_card
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
        tools/kpt
    )
    for repo in ${SDK_EXCLUDE_REPOS[@]}; do
        # replace "/" by "\/" via bash magic ${repo//\//\\/}
        sed --in-place "/ ${repo//\//\\/} /d" ${VERSION_INFO_FILE}
    done

    local SDK_EXCLUDES=(
        # remove all astyle prepare scripts
        astyle_prepare_submodule.sh

        # remove internal files in the sandbox root folder
        ./astyle_check_sdk.sh
        ./astyle_check_submodule.sh
        ./astyle_options_default
        ./build-sdk.sh
        ./jenkinsfile-control
        ./jenkinsfile-generic
        ./publish_doc.sh

        # remove internal script
        ./scripts/open_trentos_analysis_env.sh

        # remove unwanted repos
        ${SDK_EXCLUDE_REPOS[@]/#/./} # prefix every element with "./"

        # remove all readme files except from os_core_api which shall be
        # included in the doxygen documentation
        ./README.md
        ./components/ChanMux/README.md
        ./components/CertServer/README.md
        ./components/CryptoServer/README.md
        ./components/EntropySource/README.md
        ./components/NIC_ChanMux/README.md
        ./components/NIC_Dummy/README.md
        ./components/NIC_iMX6/README.md
        ./components/NIC_RPi/README.md
        ./components/RamDisk/README.md
        ./components/RPi_SPI_Flash/README.md
        ./components/SdHostController/README.md
        ./components/Storage_ChanMux/README.md
        ./components/StorageServer/README.md
        ./components/TimeServer/README.md
        ./components/TlsServer/README.md
        ./components/UART/README.md
        ./libs/chanmux/README.md
        ./libs/chanmux_nic_driver/README.md
        ./libs/lib_compiler/README.md
        ./libs/lib_debug/README.md
        ./libs/lib_host/README.md
        ./libs/lib_io/README.md
        ./libs/lib_logs/README.md
        ./libs/lib_macros/README.md
        ./libs/lib_mem/README.md
        ./libs/lib_osal/README.md
        ./libs/lib_server/README.md
        ./libs/lib_utils/README.md
        ./libs/os_cert/README.md
        ./libs/os_configuration/README.md
        ./libs/os_crypto/README.md
        ./libs/os_filesystem/README.md
        ./libs/os_keystore/README.md
        ./libs/os_logger/Readme.md
        ./libs/os_network_stack/README.md
        ./libs/os_tls/README.md
        #./os_core_api/README.md
        ./resources/README.md
        ./resources/rpi3_sd_card/README.md
        ./resources/rpi4_sd_card/README.md
        ./resources/zcu102_sd_card/README.md
        ./scripts/README.md
        ./sdk-sel4-camkes/README.md
        ./tools/cpt/README.md
        ./tools/proxy/README.md
        ./tools/rdgen/README.md
        ./tools/rpi3_flasher/README.md

        # remove imx6_sd_card resources, requires special handling
        ./resources/imx6_sd_card
    )

    # copy files using tar and filtering. Seems there is a bug in tar, for
    # "--exclude '.gitmodules'" the file .gitmodules is not excluded. So we
    # trust in "--exclude-vcs" to do the job properly.
    copy_files_via_tar \
        ${SDK_SRC_DIR} \
        ${OUT_PKG_DIR} \
        --exclude-vcs \
        ${SDK_EXCLUDES[@]/#/--exclude } # prefix all with "--exclude "

    copy_imx6_resources \
        ${SDK_SRC_DIR}/resources/imx6_sd_card \
        ${OUT_PKG_DIR}/resources

    # copy the OpenOCD configuration files for all available platforms
    # to the resources/openocd_cfgs directory
    copy_files_via_tar \
        ${SDK_SRC_DIR}/resources/openocd_cfgs \
        ${OUT_PKG_DIR}/resources/openocd_cfgs

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
            --exclude 'astyle_prepare_submodule.sh'
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
        return 1
    fi

    # there is always at least the hello world demo, so this folder can't be
    # missing
    if [ ! -d ${SDK_DEMOS_DIR} ]; then
        echo "missing SDK demo folder, did you run the collect step?"
        return 1
    fi

    local TARGETS=(
        zynq7000
        rpi3
        rpi4
        sabre
        # migv
    )

    # not every demo works on all platforms
    #
    #                      | zynq7000 | rpi3 | rpi4  | sabre | migv | ...
    # ---------------------+----------+------+-------+-------+------+
    #  demo_hello_world    | yes      | yes  | yes   | yes   | yes  |
    #  demo_iot_app        | yes      | no   | no    | no    | no   |
    #  demo_iot_app_rpi3   | no       | yes  | no    | no    | no   |
    #  demo_tls_api        | yes      | no   | no    | no    | no   |
    #
    declare -A TARGET_RESTRICTIONS=(
        [demo_iot_app]=zynq7000
        [demo_iot_app_rpi3]=rpi3
        [demo_tls_api]=zynq7000
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
            # SDK package already anyway, so we can't simply copy the images.
            #
            # mkdir -p ${SDK_DEMO_BASE}/bin
            # cp ${SDK_DEMO_OUT}/images/os_image.elf \
            #    ${SDK_DEMO_BASE}/bin/os_image-${TARGET}.bin
        done
    done
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
        return 1
    fi

    local BUILD_TESTS_DIR=${BUILD_DIR}/test_libs

    # Build tests.
    local BUILD_PARAMS=(
        ${BUILD_TESTS_DIR}     # build output folder
        all                    # build target
        ${SDK_SRC_DIR}/libs    # source folder with CMakeLists.txt
        # custom build params start here
        -DBUILD_TESTING=ON
    )
    cmake_check_init_and_build ${BUILD_PARAMS[@]}

    # Run tests and ignore errors so that the test coverage can be calculated in
    # the next step as otherwise a failing test would stop the script.
    local TEST_RET=0
    cmake --build ${BUILD_DIR}/test_libs --target test || TEST_RET=$?

    # Calculate tests coverage.
    cmake --build ${BUILD_DIR}/test_libs --target covr

    if [ ${TEST_RET} -ne 0 ]; then
        echo "SDK unit tests failed, code ${TEST_RET}"
        return 1
    fi
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
        return 1
    fi

    local BUILD_PARAMS=(
        ${BUILD_DIR}                # build output folder
        all                         # build target
        ${SDK_SRC_DIR}/${SDK_TOOL}  # source folder with CMakeLists.txt
        # custom build params start here
        # ensure SDK_SRC_DIR is an absolute path, so it can be found even if we
        # change folders during the build process
        -D OS_SDK_PATH:PATH=$(realpath ${SDK_SRC_DIR})

        # SDK tools' build type is release with debugging info so that binaries
        # are at the same time optimized and debug-able, what might be useful
        # when analyzing tools related issues.
        -D CMAKE_BUILD_TYPE=RelWithDebInfo
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

    print_info "Building SDK tools into ${OUT_DIR} from ${SDK_SRC_DIR}"

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        return 1
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

    # build RPi3 flasher tool using a dummy file
    print_info "Building SDK tool: rpi3_flasher"
    local FLASHER_SRC_TEST=${BUILD_DIR}/rpi3_flasher_src_test
    copy_files_via_tar ${SDK_SRC_DIR}/tools/rpi3_flasher ${FLASHER_SRC_TEST} --exclude-vcs

    # create a dummy file with a RLE-compressed RAM-Disk containing 0x42
    cat <<EOF >${FLASHER_SRC_TEST}/flash.c
// auto generated file
#include <stdint.h>
#include <stddef.h>
uint8_t RAMDISK_IMAGE[] = { 0x52, 0x4c, 0x45, 0x00, 0x00, 0x00, 0x01, 0x01, 0x42 };
size_t RAMDISK_IMAGE_SIZE = sizeof(RAMDISK_IMAGE);

EOF

    local BUILD_PARAMS=(
        ${FLASHER_SRC_TEST}
        rpi3
        ${BUILD_DIR}/rpi3_flasher_test
        -D CMAKE_BUILD_TYPE=Debug
    )
    ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}

}


#-------------------------------------------------------------------------------
function build_sdk_docs()
{
    local SDK_SRC_DIR=$1
    local OUT_DIR=$2

    print_info "Building SDK docs into ${OUT_DIR} from ${SDK_SRC_DIR}"

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        return 1
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
        export DOXYGEN_INPUT_DIR=os_core_api
        doxygen Doxyfile
    )

    # collect all the PDFs from the sandbox directory
    local SDK_PDF_DIR=${OS_SDK_PATH}/sdk-pdfs
    local OUT_DIR_PDF=${OUT_DIR}/pdf
    echo "Collecting PDF documentation in ${OUT_DIR_PDF}/..."

    PDF_FILES=(
        TRENTOS-M_GettingStarted_SDK_V1.2.pdf
        TRENTOS-M_Handbook_SDK_V1.2.pdf
        TRENTOS-M_MigrationNotes_SDK_V1.1_to_V1.2.pdf
        TRENTOS-M_ReleaseNotes_SDK_V1.2.pdf
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
        return 1
    fi

    local SDK_PACKAGE_BZ2=sdk-package.tar.bz2

    # All files in the SDK package will be set to the same timestamp, which is
    # the time when this script runs. Change this to enforce a specific
    # timestamp (e.g. "UTC 2021-02-19 18:00:00") for official releases.
    local SDK_PACKET_TIMESTAMP="UTC $(date --utc +'%Y-%m-%d %H:%M:%S')"

    print_info "Packaging SDK with timestamp '${SDK_PACKET_TIMESTAMP}' to ${SDK_PACKAGE_BZ2}"

    du -sh ${SDK_SRC_DIR}

    local SDK_PACKAGE_EXCLUDES=(
        # remove prepare_test.sh from demos
        prepare_test.sh
        # remove readme file from os_core_api
        ./os_core_api/README.md
        # remove all doxygen files from our modules
        ./Doxyfile
        ./libs/chanmux/Doxyfile
        ./libs/chanmux_nic_driver/Doxyfile
        ./libs/os_cert/Doxyfile
        ./libs/os_configuration/Doxyfile
        ./os_core_api/Doxyfile
        ./libs/os_crypto/Doxyfile
        ./libs/os_filesystem/Doxyfile
        ./libs/os_keystore/Doxyfile
        ./libs/os_logger/Doxyfile
        ./libs/os_network_stack/Doxyfile
        ./libs/os_tls/Doxyfile
        # remove unit-tests
        ./libs/CMakeLists.txt
        ./libs/test
        ./libs/lib_compiler/mocks
        ./libs/lib_debug/mocks
        ./libs/lib_host/test
        ./libs/lib_logs/mocks
        ./libs/lib_macros/mocks
        ./libs/lib_mem/mocks
        ./libs/lib_mem/test
        ./libs/lib_osal/mocks
        ./libs/lib_server/test
        ./libs/lib_utils/mocks
        ./libs/lib_utils/test
    )

    # Create the SDK package where all files have the same well defined
    # timestamp. The exclude list is simply built by prefixing everything in
    # SDK_PACKAGE_EXCLUDES with "--exclude ".
    tar \
        -cjf ${SDK_PACKAGE_BZ2} \
        --sort=name \
        --mtime="${SDK_PACKET_TIMESTAMP}" \
        -C ${SDK_SRC_DIR} \
        ${SDK_PACKAGE_EXCLUDES[@]/#/--exclude } \
        .

    du -sh ${SDK_PACKAGE_BZ2}
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
ACTION=$1
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
        collect-sources)
            collect_sdk_sources ${OS_SDK_PATH} ${OUT_BASE_DIR} ${SDK_PACKAGE_SRC}
            ;;

        build-package)
            package_sdk ${SDK_PACKAGE_SRC}
            ;;

        run-unit-tests)
            sdk_unit_test ${SDK_PACKAGE_SRC} ${SDK_UNIT_TEST}
            ;;

        build-docs)
            build_sdk_docs ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DOC}
            ;;

        build-tools)
            build_sdk_tools ${SDK_PACKAGE_SRC} ${SDK_BUILD} ${SDK_PACKAGE_BIN}
            ;;

        collect-demos)
            collect_sdk_demos ${DEMOS_SRC_DIR} ${SDK_PACKAGE_DEMOS}
            ;;

        build-demos)
            build_sdk_demos ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DEMOS} ${SDK_BUILD}
            ;;

        create-package)
            do_sdk_step collect-sources
            do_sdk_step build-tools
            # collect demos after tool build to ensure there is no dependency
            do_sdk_step collect-demos
            # documentation build also covers demos
            do_sdk_step build-docs
            do_sdk_step build-package
            ;;

        *)
            echo "invalid STEP: ${STEP}"
            return 1
            ;;
    esac
}


#-------------------------------------------------------------------------------
case "${ACTION}" in
    all)
        # create SDK package including docs and demos, run unit test and build
        # all demos
        do_sdk_step create-package
        do_sdk_step run-unit-tests
        do_sdk_step build-demos
        ;;

    package)
        do_sdk_step create-package
        ;;

    tools)
        # collect sources and build the SDK binaries
        do_sdk_step collect-sources
        do_sdk_step build-tools
        ;;

    demos)
        # create SDK snapshot, collect demos and build them
        do_sdk_step collect-sources
        do_sdk_step collect-demos
        do_sdk_step build-demos
        ;;

    unit-tests)
        do_sdk_step collect-sources
        do_sdk_step run-unit-tests
        ;;

    doc)
        # create SDK snapshot and build documentation from it
        do_sdk_step collect-sources
        # note that there are no demos collected here
        do_sdk_step build-docs
        ;;

    *)
        # execute requested step
        do_sdk_step ${ACTION}
esac

