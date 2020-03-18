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

# build output will be placed into a subdirectory of the current working
# directory (ie the directory where this script is invoked in)
BUILD_DIR=$1
BUILD_PLATFORM=$2
shift
# all remaining params will be passed to CMake

echo ""
echo "##"
echo "## building ${BUILD_PLATFORM} into ${BUILD_DIR}"
echo "##"

CMAKE_PARAMS=(
    -D CMAKE_TOOLCHAIN_FILE=${SEOS_SDK_DIR}/sdk-sel4-camkes/kernel/gcc.cmake
    # seL4 build system settings
    -D PLATFORM=${BUILD_PLATFORM}
    -D KernelVerificationBuild=OFF
    # SEL4_CACHE_DIR is a binary cache. There are some binaries (currently
    # musllibc and capDL-toolthat) that project agnostic, so we don't have
    # to rebuild them every time. This reduces the build time a lot.
    -D SEL4_CACHE_DIR=cache-${BUILD_PLATFORM}
)

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
        CMAKE_PARAMS+=(
            -D CROSS_COMPILER_PREFIX=arm-linux-gnueabi-
        )
        ;;
    #-------------------------------------
    fvp  |\
    imx8mq-evk | imx8mm-evk |\
    odroidc2 |\
    rockpro64 |\
    tx1 |\
    tx2 |\
    zynqmp | zynqmp-zcu102 | zynqmp-ultra96 | ultra96 )
        CMAKE_PARAMS+=(
            -D CROSS_COMPILER_PREFIX=aarch64-linux-gnu-
        )
        ;;
    #-------------------------------------
    ariane |\
    hifive |\
    spike )
        CMAKE_PARAMS+=(
            -D CROSS_COMPILER_PREFIX=riscv64-unknown-linux-gnu-
        )
        ;;
    #-------------------------------------
    pc99)
        CMAKE_PARAMS+=(
            -D CROSS_COMPILER_PREFIX=x86_64-linux-gnu-
        )
        ;;
    #-------------------------------------
    *)
        echo "invalid platform: ${BUILD_PLATFORM}"
        exit 1
        ;;
esac

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
            cmake ${CMAKE_PARAMS[@]} $@ -G Ninja ${SEOS_SDK_DIR}
        )

        # must run cmake multiple times, so config settings propagate properly
        echo "re-run cmake (1/2)"
        cmake .
        echo "re-run cmake (2/2)"
        cmake .
    )
fi

# build in subshell
(
    cd ${BUILD_DIR}
    ninja all
)
