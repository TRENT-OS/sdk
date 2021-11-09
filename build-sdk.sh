#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Script to build SDK packages.
#
# Copyright (C) 2020-2021, HENSOLDT Cyber GmbH
#
#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# This script assumes it is located in the SDK root folder
OS_SDK_PATH="${SCRIPT_DIR}"

# WARNING: This script assumes it exists in a directory structure like the one
# of seos_tests. The CI job has to check out the demos according to this layout
# before running the script in order to build the SDK package.
DEMOS_SRC_DIR="${SCRIPT_DIR}/../src/demos"

# Name of the version info file.
VERSION_INFO_FILENAME="version.info"


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
function collect_sdk_sandbox()
{
    local SDK_SRC_DIR=$1
    local OUT_BASE_DIR=$2
    local OUT_PKG_DIR=$3
    shift 3

    #---------------------------------------------------------------------------
    # Prepare clean output folder.
    #---------------------------------------------------------------------------

    if [ -d ${OUT_PKG_DIR} ]; then
        rm -rf ${OUT_PKG_DIR}
    fi

    mkdir -p ${OUT_PKG_DIR}

    #---------------------------------------------------------------------------
    # Create version file with git submodule infos.
    #---------------------------------------------------------------------------

    local VERSION_INFO_FILE=${OUT_BASE_DIR}/${VERSION_INFO_FILENAME}

    local ABS_VERSION_INFO_FILE=$(realpath ${VERSION_INFO_FILE})
    (
        cd ${SDK_SRC_DIR}
        git submodule status --recursive > ${ABS_VERSION_INFO_FILE}
    )

    #---------------------------------------------------------------------------
    # Prepare basic sandbox excludes.
    # NOTE: Specify files that are not needed for the SDK build process. Further
    # exclusions are possible in package_sdk().
    #---------------------------------------------------------------------------

    local BASIC_SANDBOX_EXCLUDES=(
        # remove all astyle prepare scripts
        astyle_prepare_submodule.sh

        # remove internal files in the sandbox root folder
        ./build-sdk.sh
        ./publish_doc.sh

        # remove jenkins files
        ./jenkinsfile
        ./jenkinsfile-control
        ./jenkinsfile-generic

        # remove axivion scripts
        ./scripts/axivion
        ./scripts/open_trentos_analysis_env.sh

        # remove unwanted repos
        ./sdk-pdfs
        ./tools/kpt

        # remove all readme files except from os_core_api which shall be
        # included in the doxygen documentation
        ./README.md
        ./components/*/README.md
        ./libs/*/README.md
        #./os_core_api/README.md # remove later after doxygen
        ./resources/README.md
        ./resources/*/README.md
        ./scripts/README.md
        ./sdk-sel4-camkes/README.md
        ./tools/*/README.md

        # remove unwanted resources
        ./resources/rpi4_sd_card
        ./resources/scripts
        ./resources/zcu102_sd_card

        # remove imx6_sd_card resources, requires special handling
        ./resources/imx6_sd_card

        # remove keystore_ram_fv test folder
        ./libs/os_keystore/os_keystore_ram_fv/keystore_ram_fv/test
    )

    #---------------------------------------------------------------------------
    # Copy SDK sources using tar and filtering, this is faster and more flexibel
    # than the cp command.
    # NOTE: Use "--exclude-vcs" to exclude vcs directories since there seems to
    # be a bug in tar when using "--exclude .gitmodules".
    #---------------------------------------------------------------------------

    print_info "Copying SDK sources from ${SDK_SRC_DIR} to ${OUT_PKG_DIR}"

    copy_files_via_tar \
        ${SDK_SRC_DIR} \
        ${OUT_PKG_DIR} \
        --exclude-vcs \
        --no-wildcards-match-slash \
        ${BASIC_SANDBOX_EXCLUDES[@]/#/--exclude } # prefix with "--exclude "

    #---------------------------------------------------------------------------
    # Special handling for imx6 resources.
    # NOTE: Some files are in a common folder in the resources repository and
    # need to be copied to the specific platform folders.
    #---------------------------------------------------------------------------

    local RES_SRC_DIR=${SDK_SRC_DIR}/resources/imx6_sd_card
    local RES_DST_DIR=${OUT_PKG_DIR}/resources

    print_info "Copying imx6 resources from ${RES_SRC_DIR} to ${RES_DST_DIR}"

    copy_files_via_tar \
        ${RES_SRC_DIR}/nitrogen6sx \
        ${RES_DST_DIR}/nitrogen6sx_sd_card

    copy_files_via_tar \
        ${RES_SRC_DIR}/common \
        ${RES_DST_DIR}/nitrogen6sx_sd_card

    copy_files_via_tar \
        ${RES_SRC_DIR}/sabre \
        ${RES_DST_DIR}/sabre_sd_card

    copy_files_via_tar \
        ${RES_SRC_DIR}/common \
        ${RES_DST_DIR}/sabre_sd_card
}


#-------------------------------------------------------------------------------
function collect_sdk_demos()
{
    local DEMOS_DIR=$1
    local OUT_BASE_DIR=$2
    local SDK_PACKAGE_DEMOS=$3
    shift 3

    for SDK_DEMO_NAME in $(ls ${DEMOS_DIR}) ; do

        local DEMO_SRC_DIR=${DEMOS_DIR}/${SDK_DEMO_NAME}
        local DEMO_DST_DIR=${SDK_PACKAGE_DEMOS}/${SDK_DEMO_NAME}

        # Record git revision of demo.
        echo " $(cd ${DEMO_SRC_DIR}; git rev-parse HEAD) ${SDK_DEMO_NAME}" \
             >> ${OUT_BASE_DIR}/${VERSION_INFO_FILENAME}

        #-----------------------------------------------------------------------
        # Prepare basic demo excludes.
        # NOTE: Specify files that are not needed for the SDK build process.
        # Further exclusions are possible in package_sdk().
        #-----------------------------------------------------------------------

        local BASIC_DEMO_EXCLUDES=(
            ./axivion
            ./README.md
        )

        #-----------------------------------------------------------------------
        # Copy demo sources using tar and filtering, this is faster and more
        # flexibel than the cp command.
        # NOTE: Use "--exclude-vcs" to exclude vcs directories since there seems
        # to be a bug in tar when using "--exclude .gitmodules".
        #-----------------------------------------------------------------------

        print_info "Copying demo sources from ${DEMO_SRC_DIR} to ${DEMO_DST_DIR}"

        copy_files_via_tar \
            ${DEMO_SRC_DIR} \
            ${DEMO_DST_DIR} \
            --exclude-vcs \
            --no-wildcards-match-slash \
            ${BASIC_DEMO_EXCLUDES[@]/#/--exclude } # prefix with "--exclude "
    done
}


#-------------------------------------------------------------------------------
function sdk_sanity_check()
{
    local SDK_SRC_DIR=$1
    local SDK_DEMOS_DIR=$2
    local BUILD_DIR=$3
    shift 3

    local DEMO_NAME="demo_hello_world"
    local DEMO_TARGET="zynq7000"
    local DEMO_BUILD_TYPE="Debug"

    print_info "Building ${DEMO_NAME} for ${DEMO_TARGET} as a sanity check for the SDK package."

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK folder, did you run the collect step?"
        return 1
    fi

    if [ ! -d ${SDK_DEMOS_DIR}/${DEMO_NAME} ]; then
        echo "missing ${DEMO_NAME} folder, did you run the collect step?"
        return 1
    fi

    local DEMO_BUILD_DIR=${BUILD_DIR}/${DEMO_NAME}-${DEMO_TARGET}

    local BUILD_PARAMS=(
        ${SDK_DEMOS_DIR}/${DEMO_NAME}
        ${DEMO_TARGET}
        ${DEMO_BUILD_DIR}
        -D CMAKE_BUILD_TYPE=${DEMO_BUILD_TYPE}
    )

    ${SDK_SRC_DIR}/build-system.sh ${BUILD_PARAMS[@]}
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
    local OUT_DOC_DIR=$2

    print_info "Building SDK docs into ${OUT_DOC_DIR} from ${SDK_SRC_DIR}"

    if [ ! -d ${SDK_SRC_DIR} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        return 1
    fi

    # Ensure the doc folder exists and is empty.
    rm -rf ${OUT_DOC_DIR}
    mkdir -p ${OUT_DOC_DIR}

    #---------------------------------------------------------------------------
    # Create the Doxygen documentation of the os_core_api.
    # TODO: Create documentation of the entire SDK once it is well documented.
    #---------------------------------------------------------------------------

    echo "Generating Doxygen documentation into ${OUT_DOC_DIR}"

    (
        export DOXYGEN_INPUT_DIR="os_core_api"
        export DOXYGEN_OUTPUT_DIR=$(realpath ${OUT_DOC_DIR})

        cd ${SDK_SRC_DIR}
        doxygen Doxyfile
    )

    #---------------------------------------------------------------------------
    # Copy PDF files from the sdk-pdfs repository.
    #---------------------------------------------------------------------------

    local SDK_PDF_DIR=${OS_SDK_PATH}/sdk-pdfs
    local OUT_PDF_DIR=${OUT_DOC_DIR}/pdf

    echo "Copying all PDF files into ${OUT_PDF_DIR} from ${SDK_PDF_DIR}"

    copy_files_via_tar \
        ${SDK_PDF_DIR} \
        ${OUT_PDF_DIR} \
        --exclude-vcs
}


#-------------------------------------------------------------------------------
function package_sdk()
{
    local SDK_PACKAGE_SRC=$1
    shift 1

    if [ ! -d ${SDK_PACKAGE_SRC} ]; then
        echo "missing SDK source folder, did you run the collect step?"
        return 1
    fi

    # Name of the development SDK package (for testing).
    local DEV_SDK_PACKAGE=dev-sdk-package.tar.bz2
    # Name of the SDK package (for releases).
    local SDK_PACKAGE=sdk-package.tar.bz2

    # All files in the packages will be set to the same timestamp, which is the
    # time when this script runs.
    # To enforce a specific timestamp for official releases the variable should
    # be hard-coded on the release branch, e.g. to "UTC 2021-02-19 18:00:00".
    local TIMESTAMP="UTC 2021-11-09 14:00:00"

    print_info "Start creating packages from ${SDK_PACKAGE_SRC} with timestamp '${TIMESTAMP}':"
    du -sh ${SDK_PACKAGE_SRC}

    #---------------------------------------------------------------------------
    # Create development SDK package.
    # This package is used for internal testing. Only a basic filtering has been
    # applied based on the sandbox and demo repositories during the collection.
    #---------------------------------------------------------------------------

    print_info "Create development SDK package ${DEV_SDK_PACKAGE}:"

    # - Apply timestamp to all files.
    tar \
        -cjf ${DEV_SDK_PACKAGE} \
        --sort=name \
        --mtime="${TIMESTAMP}" \
        -C ${SDK_PACKAGE_SRC} \
        .

    du -sh ${DEV_SDK_PACKAGE}

    #---------------------------------------------------------------------------
    # Create SDK package.
    # This package is used for releases. Compared to the development SDK package
    # a further filtering is applied to remove not-to-be-released files.
    #---------------------------------------------------------------------------

    print_info "Create SDK package ${SDK_PACKAGE}:"

    du -sh ${SDK_PACKAGE_SRC}

    local SDK_PACKAGE_EXCLUDES=(
        # remove astyle scripts
        ./astyle_check_sdk.sh
        ./astyle_check_submodule.sh
        ./astyle_options_default
        astyle_prepare_submodule.sh

        # remove development components
        ./components/SysLogger

        # remove files from documentation
        ./doc/pdf/README.md

        # remove prepare_test.sh from demos
        prepare_test.sh

        # remove files used by doxygen
        ./Doxyfile
        ./os_core_api/README.md

        # remove unit-tests
        ./libs/CMakeLists.txt
        ./libs/test
        ./libs/*/mocks
        ./libs/*/test
    )

    # - Apply timestamp to all files.
    # - Prefix excludes with "--exclude ".
    tar \
        -cjf ${SDK_PACKAGE} \
        --no-wildcards-match-slash \
        --sort=name \
        --mtime="${TIMESTAMP}" \
        -C ${SDK_PACKAGE_SRC} \
        ${SDK_PACKAGE_EXCLUDES[@]/#/--exclude } \
        .

    du -sh ${SDK_PACKAGE}
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
ACTION=$1
OUT_BASE_DIR=$2
shift 2

# for development purposes, all the steps can also run directly from the SDK
# sources. In this case don't run "collect_sdk_sandbox" and set SDK_PACKAGE_SRC
# to OS_SDK_PATH for all steps


SDK_BUILD=${OUT_BASE_DIR}/build
SDK_UNIT_TEST=${OUT_BASE_DIR}/unit-tests
SDK_PACKAGE_SRC=${OUT_BASE_DIR}/pkg
SDK_PACKAGE_DOC=${SDK_PACKAGE_SRC}/doc
SDK_PACKAGE_BIN=${SDK_PACKAGE_SRC}/bin

# WARNING: The folder 'demos' is required by CI to build SDK demos against the
#          SDK package.
SDK_PACKAGE_DEMOS=${SDK_PACKAGE_SRC}/demos


#-------------------------------------------------------------------------------
function do_sdk_step()
{
    local STEP=$1

    case "${STEP}" in
        collect-sources)
            collect_sdk_sandbox ${OS_SDK_PATH} ${OUT_BASE_DIR} ${SDK_PACKAGE_SRC}
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
            collect_sdk_demos ${DEMOS_SRC_DIR} ${OUT_BASE_DIR} ${SDK_PACKAGE_DEMOS}
            ;;

        sanity-check)
            sdk_sanity_check ${SDK_PACKAGE_SRC} ${SDK_PACKAGE_DEMOS} ${SDK_BUILD}
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
        # create SDK package including docs and demos, run unit test and do the
        # build hello world sanity check
        do_sdk_step create-package
        do_sdk_step run-unit-tests
        do_sdk_step sanity-check
        ;;

    package)
        do_sdk_step create-package
        ;;

    tools)
        # collect sources and build the SDK binaries
        do_sdk_step collect-sources
        do_sdk_step build-tools
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

