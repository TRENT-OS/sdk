#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# SDK Build Script
#
# Copyright (C) 2020-2021, HENSOLDT Cyber GmbH
#
#-------------------------------------------------------------------------------
#
# This script must be invoked as
#
#     <SDK>/build-system.sh
#             <OS_PROJECT_DIR>
#             <BUILD_PLATFORM>
#             <BUILD_DIR>
#             -D CMAKE_BUILD_TYPE=<Debug|Release|...>
#             ...
#
# Where
#
#    SDK
#       is the path to the SDK.
#
#    OS_PROJECT_DIR
#       is the path to the OS project to build.
#
#    BUILD_PLATFORM
#       is the target platform, refer to the seL4 build system for details.
#
#    BUILD_DIR
#       is the folder where the build output will be created in, usually a
#       sub-directory of the folder where the script is invoked in (ie. the
#       current working directory).
#
#    -D CMAKE_BUILD_TYPE=<Debug|Release|...>
#       is a CMake parameter required by the seL4/CAmkES build system, refer to
#       the seL4 build system for details.
#
# Any additional parameters will be passed to CMake.
#
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# In order to debug a sporadic issue in CI we print this debug information as
# first commands executed in the freshly started container
echo ""
echo "*************************************************************************"
echo "In order to debug a sporadic CI issue we collect debug info here"
echo "Timestamp: `date`"
echo "Lock file: `ls -la /run/fixuid.ran`"
echo "Lock file: `ls -la /var/run/fixuid.ran`"
echo "UID: `id`"
echo "groups: `groups`"
echo "HOME: *${HOME}*"
echo "*************************************************************************"
echo ""

#-------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# This script assumes it is located in the SDK root folder. We need the absolute
# SDK path because we change the current working directory in the build process.
ABS_OS_SDK_PATH="$(realpath ${SCRIPT_DIR})"

# read parameters
OS_PROJECT_DIR=$1
BUILD_PLATFORM=$2
BUILD_DIR=$3
shift 3
# all remaining parameters will be passed to CMake
BUILD_ARGS="$@"
BUILD_ARGS_FILE=build.args

echo ""
echo "##=============================================================================="
echo "## Project:   ${OS_PROJECT_DIR}"
echo "## Platform:  ${BUILD_PLATFORM}"
echo "## Output:    ${BUILD_DIR}"
echo "##------------------------------------------------------------------------------"

case "${BUILD_PLATFORM}" in
    #-------------------------------------
    am335x | am335x-boneblack | am335x-boneblue | \
    apq8064 |\
    bcm2837 | rpi3 | bcm2837-rpi3 |\
    exynos4 |\
    exynos5 | exynos5250 | exynos5410 | exynos5422 |\
    hikey |\
    imx6 | sabre | imx6-sabre | wandq | imx6-wandq |\
    imx7  | imx7-sabre |\
    imx31 | kzm | imx31-kzm |\
    omap3 |\
    qemu-arm-virt |\
    tk1 |\
    zynq7000 )
        CROSS_COMPILER_PREFIX=arm-linux-gnueabi-
        ;;
    #-------------------------------------
    fvp |\
    imx8mq-evk | imx8mm-evk |\
    odroidc2 |\
    rockpro64 |\
    tx1 |\
    tx2 |\
    zynqmp | zynqmp-zcu102 | zynqmp-ultra96 | ultra96 )
        CROSS_COMPILER_PREFIX=aarch64-linux-gnu-
        ;;
    #-------------------------------------
    ariane |\
    hifive |\
    spike )
        CROSS_COMPILER_PREFIX=riscv64-unknown-linux-gnu-
        ;;
    #-------------------------------------
    pc99 |\
    x86_64 |\
    ia32)
        CROSS_COMPILER_PREFIX=x86_64-linux-gnu-
        ;;
    #-------------------------------------
    *)
        echo "invalid platform: ${BUILD_PLATFORM}"
        exit 1
        ;;
esac

CMAKE_PARAMS=(
    # CMake settings
    -D CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX}
    -D CMAKE_TOOLCHAIN_FILE:FILEPATH=${ABS_OS_SDK_PATH}/sdk-sel4-camkes/kernel/gcc.cmake
    # seL4 build system settings
    -D PLATFORM=${BUILD_PLATFORM}
    -D KernelVerificationBuild=OFF
    # SEL4_CACHE_DIR is a binary cache. There are some binaries (currently
    # musllibc and capDL-tool) that are project agnostic, so we don't have
    # to rebuild them every time. This reduces the build time a lot.
    -D SEL4_CACHE_DIR:PATH=cache-${BUILD_PLATFORM}
    # Location of the OS project to be built. Since we will change the current
    # working directory, we have to ensure this is an absolute path.
    -D OS_PROJECT_DIR:PATH=$(realpath ${OS_PROJECT_DIR})
)


if [[ -d ${BUILD_DIR} ]]; then
    # If there is already a build configuration folder, chances are high that
    # a previous configured build already exists and we don't have to start the
    # CMake build config process from scratch, but just do a rebuild based on
    # the changes. The easiest way to check this is looking for a ninja rule
    # file to exist. Usually, if the CMake config step failed already, this
    # file is not created and it is best to wipe the build folder and start from
    # scratch. The next check is to determine if the manual build configuration
    # has changed, i. e. if additional command line parameters have been used
    # for the last build and these match the command line parameters of this
    # build. If not, then we have to wipe the build folder and start from
    # scratch to guarantee the new command line parameters are taken properly
    # into account everywhere.
    if [[ ! -e ${BUILD_DIR}/rules.ninja ]]; then
        echo "deleting broken build folder and re-initialize it"
        rm -rf ${BUILD_DIR}
    elif [[ ( ! -e ${BUILD_DIR}/${BUILD_ARGS_FILE} && ! -z "${BUILD_ARGS}") \
            || "$(< ${BUILD_DIR}/${BUILD_ARGS_FILE})" != "${BUILD_ARGS}" ]]; then
        # ToDo: We could define that a command line with no build arguments
        #       does take what was stored in the argument file. However, it
        #       turned out this does not match the common workflow. Usually, a
        #       command line is rarely typed in, but for re-builds one just
        #       takes a command line from the shell's history buffer. Thus,
        #       specifying no arguments is usually intended to explicitly
        #       trigger a build with the default configuration.
        echo "build parameters have changed, rebuild everything"
        rm -rf ${BUILD_DIR}
    fi

fi

if [[ ! -d ${BUILD_DIR} ]]; then

    echo "configure build ..."
    echo "##------------------------------------------------------------------------------"

    mkdir -p ${BUILD_DIR}

    # save build args
    echo "${BUILD_ARGS}" > ${BUILD_DIR}/${BUILD_ARGS_FILE}

    # use subshell to make CMake set up the build environment
    (
        cd ${BUILD_DIR}
        set -x
        cmake ${CMAKE_PARAMS[@]} ${BUILD_ARGS} -G Ninja ${ABS_OS_SDK_PATH}
    )

    # cmake must run twice, so the config settings propagate properly. The
    # first runs populates the cache and the second run will find the correct
    # settings in the cache to set up the build.
    echo "##------------------------------------------------------------------------------"
    echo "re-run cmake ..."
    echo "##------------------------------------------------------------------------------"

    cmake ${BUILD_DIR}

    # create a visualization of the build targets
    echo "create build target graph"
    BUILD_TARGETS_GRAPH=build-targets-graph
    mkdir -p ${BUILD_DIR}/${BUILD_TARGETS_GRAPH}
    (
        cd ${BUILD_DIR}/${BUILD_TARGETS_GRAPH}
        cmake --graphviz=${BUILD_TARGETS_GRAPH}.dot .. > /dev/null
        dot -Tsvg ${BUILD_TARGETS_GRAPH}.dot -o ../${BUILD_TARGETS_GRAPH}.svg
    )

    echo "##------------------------------------------------------------------------------"
    echo "start actual build ..."
    echo "##------------------------------------------------------------------------------"
fi

cmake --build ${BUILD_DIR} --target all

echo "##------------------------------------------------------------------------------"
echo "## build successful, output in ${BUILD_DIR}"
echo "##=============================================================================="
