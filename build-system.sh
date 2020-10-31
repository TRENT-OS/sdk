#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# SDK OS Build script
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
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

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# This script assumes it is located in the SDK root folder. We need the
# absolute SDK path, because we change the current working directory in the
# build  process
ABS_OS_SDK_PATH="$(realpath ${SCRIPT_DIR})"

# read parameters
OS_PROJECT_DIR=$1
BUILD_PLATFORM=$2
BUILD_DIR=$3
shift 3
# all remaining params will be passed to CMake

echo ""
echo "##======================================================================="
echo "## Project:   ${OS_PROJECT_DIR}"
echo "## Platform:  ${BUILD_PLATFORM}"
echo "## Output:    ${BUILD_DIR}"
echo "##-----------------------------------------------------------------------"

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
    pc99)
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
    # location of the OS project to be build. Since we will change the current
    # working directory, we have to ensure this is an absolute path
    -D OS_PROJECT_DIR:PATH=$(realpath ${OS_PROJECT_DIR})
)

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
        (
            set -x
            cmake ${CMAKE_PARAMS[@]} $@ -G Ninja ${ABS_OS_SDK_PATH}
        )

        # cmake must run twice, so the config settings propagate properly. The
        # first runs populates the cache and the second run will find the
        # correct settings in the cache to set up the build.
        echo "re-run cmake"
        cmake .

        # create a visualization of the build targets
        echo "create build target graph"
        BUILD_TARGETS_GRAPH=build-targets-graph
        mkdir -p ${BUILD_TARGETS_GRAPH}
        (
            cd ${BUILD_TARGETS_GRAPH}
            cmake --graphviz=${BUILD_TARGETS_GRAPH}.dot .. > /dev/null
            dot -Tsvg ${BUILD_TARGETS_GRAPH}.dot -o ../${BUILD_TARGETS_GRAPH}.svg
        )
    )
fi

# build in subshell
(
    cd ${BUILD_DIR}
    cmake --build . --target all
)

echo "##-----------------------------------------------------------------------"
echo "## build successful, output in ${BUILD_DIR}"
echo "##======================================================================="

