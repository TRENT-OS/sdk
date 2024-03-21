#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Generic Build Script
#
# Copyright (C) 2020-2024, HENSOLDT Cyber GmbH
# 
# SPDX-License-Identifier: GPL-2.0-or-later
#
# For commercial licensing, contact: info.cyber@hensoldt.net
#
#-------------------------------------------------------------------------------
#
# This script must be invoked as
#
#     <SDK>/build-system.sh
#             <PROJECT_DIR>
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
#    PROJECT_DIR
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
# Supported environment variables:
#
#    TOOLCHAIN=[gcc|clang]
#        Toolchain to be used, currently supported are:
#          "gcc"      use GCC toolchain, used as default if nothing is set.
#          "clang"    use LLVM/clang toolchain.
#
#    BUILD_TARGET=<target>
#       Specify the CMake build configuration target, defaults to "all" if
#       nothing is set. Currently, the main use case for different targets is
#       running the analysis with the Axivion suite.
#
#
#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

#-------------------------------------------------------------------------------
function print_error()
{
    echo ""
    echo "##"
    echo "## ERROR: $1"
    echo "##"
}

#-------------------------------------------------------------------------------
function print_new_section()
{
    echo "##------------------------------------------------------------------------------"
    echo "## $1"
    echo "##------------------------------------------------------------------------------"
}


# read parameters
if [ "$#" -lt 3 ]; then
    print_error "required parameters are <PROJECT_DIR> <BUILD_PLATFORM> <BUILD_DIR>"
    return 1
fi
PROJECT_DIR=$1
BUILD_PLATFORM=$2
BUILD_DIR=$3
shift 3
# all remaining parameters will be passed to CMake
BUILD_ARGS=("$@")

# By definition, this script is located in the SDK root folder.
OS_SDK_PATH="${SCRIPT_DIR}"

# Check if an individual CMake build target is set in the environment variable,
# for example used for analysis (default: all).
BUILD_TARGET=${BUILD_TARGET:-all}

CMAKE_PARAMS_FILE=cmake_params.txt
BUILD_TARGETS_GRAPH=build-targets-graph

# When this script is executed from Jenkins in a docker environment, a race
# condition in the Jenkins docker agent plugin could make it run before the
# container's entrypoint script has finished. This bug is tracked in
# https://issues.jenkins.io/browse/JENKINS-54389 and other tickets. In our case,
# this could mean the fixuid tool has not finished updating the runtime
# environment. Thus, if the fixuid tool exists, we assume we are in a docker
# container that runs it, and wait until it has finished.
if [ -e "/usr/local/bin/fixuid" ]; then
    until [ -f "/run/fixuid.ran" ]; do
        echo "Waiting for fixuid to finish."
        sleep 1
    done
    # In case the race condition happened, this shell script runs spawned before
    # fixuid could set up the environment variable(s). Do is manually.
    DOCKER_USER_HOME="/home/$(whoami)"
    if [ "${HOME}" != "${DOCKER_USER_HOME}" ]; then
        echo "fix env var HOME: '${HOME}' -> '${DOCKER_USER_HOME}'"
        export HOME=${DOCKER_USER_HOME}
    fi
fi

TOOLCHAIN=${TOOLCHAIN:-gcc}

CMAKE_PARAMS_PLATFORM=()

case "${BUILD_PLATFORM}" in
    #-------------------------------------
    qemu-arm-virt )
        # seL4 build system defaults to Cortex-A53
        BUILD_ARCH=aarch64
        ;;
    #-------------------------------------
    qemu-arm-virt-a15 )
        QEMU_VIRT_ARM_CPU=cortex-${BUILD_PLATFORM#qemu-arm-virt-}
        BUILD_PLATFORM=qemu-arm-virt
        BUILD_ARCH=aarch32
        CMAKE_PARAMS_PLATFORM+=( -D ARM_CPU=${QEMU_VIRT_ARM_CPU} )
        ;;
    #-------------------------------------
    qemu-arm-virt-a53 | qemu-arm-virt-a57 | qemu-arm-virt-a72)
        QEMU_VIRT_ARM_CPU=cortex-${BUILD_PLATFORM#qemu-arm-virt-}
        BUILD_PLATFORM=qemu-arm-virt
        BUILD_ARCH=aarch64
        CMAKE_PARAMS_PLATFORM+=( -D ARM_CPU=${QEMU_VIRT_ARM_CPU} )
        ;;
    #-------------------------------------
    qemu-riscv-virt )
        # seL4 build system defaults to rv64
        BUILD_ARCH=riscv64
        ;;
    #-------------------------------------
    qemu-riscv-virt32 )
        BUILD_ARCH=riscv32
        BUILD_PLATFORM=qemu-riscv-virt
        ;;
    #-------------------------------------
    qemu-riscv-virt64 )
        BUILD_ARCH=riscv64
        BUILD_PLATFORM=qemu-riscv-virt
        ;;
    #-------------------------------------
    spike32 )
        BUILD_PLATFORM=spike
        BUILD_ARCH=riscv32
        ;;
    #-------------------------------------
    spike64 | spike )
        BUILD_PLATFORM=spike
        BUILD_ARCH=riscv64
        ;;
    #-------------------------------------
    rpi4 )
        BUILD_ARCH=aarch64
        RPI4_MEMORY=4096
        ;;
    #-------------------------------------
    am335x | am335x-boneblack | am335x-boneblue | \
    apq8064 |\
    bcm2837 | rpi3 | bcm2837-rpi3 |\
    exynos4 |\
    exynos5 | exynos5250 | exynos5410 | exynos5422 |\
    hikey |\
    imx6 | sabre | imx6-sabre | wandq | imx6-wandq | nitrogen6sx |\
    imx7  | imx7-sabre |\
    imx31 | kzm | imx31-kzm |\
    omap3 |\
    tk1 |\
    zynq7000 )
        BUILD_ARCH=aarch32
        ;;
    #-------------------------------------
    fvp |\
    imx8mq-evk | imx8mm-evk |\
    odroidc2 |\
    odroidc4 |\
    rockpro64 |\
    tx1 | jetson-tx1-dev-kit | jetson-nano-2gb-dev-kit |\
    tx2 | jetson-tx2-asg001 | jetson-tx2-nx-a206 |\
    xavier | jetson-xavier-nx-dev-kit | aetina-an110-xnx |\
    zynqmp | zynqmp-zcu102 | zynqmp-ultra96 | ultra96 | ultra96v2 )
        BUILD_ARCH=aarch64
        ;;
    #-------------------------------------
    ariane |\
    hifive |\
    polarfire )
        BUILD_ARCH=riscv64
        ;;
    #-------------------------------------
    pc99 |\
    x86_64 |\
    ia32)
        BUILD_ARCH=${BUILD_PLATFORM}
        ;;
    #-------------------------------------
    *)
        print_error "invalid platform '${BUILD_PLATFORM}'"
        exit 1
        ;;
esac

case "${BUILD_ARCH}" in
    aarch32)
        CMAKE_PARAMS_PLATFORM+=( -D AARCH32=TRUE )
        TRIPLE=arm-linux-gnueabi
        ;;
    aarch64)
        CMAKE_PARAMS_PLATFORM+=( -D AARCH64=TRUE )
        TRIPLE=aarch64-linux-gnu
        ;;
    riscv32)
        CMAKE_PARAMS_PLATFORM+=( -D RISCV32=TRUE )
        # 64-bit toolchain can build 32 targets also
        TRIPLE=riscv64-unknown-elf
        ;;
    riscv64)
        CMAKE_PARAMS_PLATFORM+=( -D RISCV64=TRUE )
        TRIPLE=riscv64-unknown-elf
        ;;

    pc99 | ia32 | x86_64)
        # 64-bit toolchain can build 32 targets also
        TRIPLE=x86_64-linux-gnu
        ;;
    *)
        print_error "invalid architecture '${BUILD_ARCH}'"
        exit 1
        ;;
esac

case "${TOOLCHAIN}" in
    gcc)
        TOOLCHAIN_FILE="${OS_SDK_PATH}/sdk-sel4-camkes/kernel/gcc.cmake"
        # Luckily, CROSS_COMPILER_PREFIX can be built from TRIPLE by just adding
        # a dash.
        CMAKE_PARAMS_PLATFORM+=( -D CROSS_COMPILER_PREFIX=${TRIPLE}- )
        ;;

    clang)
        TOOLCHAIN_FILE="${OS_SDK_PATH}/sdk-sel4-camkes/kernel/llvm.cmake"
        CMAKE_PARAMS_PLATFORM+=( -D TRIPLE=${TRIPLE} )
        ;;

    *)
        print_error "unsupported toolchain '${TOOLCHAIN}'"
        exit 1
        ;;
esac

echo ""
echo "##=============================================================================="
echo "## Project:   ${PROJECT_DIR}"
echo "## Platform:  ${BUILD_PLATFORM}"
echo "## Toolchain: ${TOOLCHAIN} (${TRIPLE})"
echo "## Output:    ${BUILD_DIR}"

# Set CMake parameters
CMAKE_PARAMS=(
    # CMake settings
    -D CMAKE_TOOLCHAIN_FILE:FILEPATH=${TOOLCHAIN_FILE}
    # seL4 build system settings
    -D PLATFORM=${BUILD_PLATFORM}
    "${CMAKE_PARAMS_PLATFORM[@]}"
    -D KernelVerificationBuild=OFF
    # SEL4_CACHE_DIR is a binary cache. There are some binaries (currently
    # musllibc and capDL-tool) that are project agnostic, so we don't have
    # to rebuild them every time. This reduces the build time a lot.
    -D SEL4_CACHE_DIR:PATH=cache-${BUILD_PLATFORM}
    -D CMAKE_MODULE_PATH:PATH="${OS_SDK_PATH}"
    "${BUILD_ARGS[@]}"
    --graphviz=${BUILD_TARGETS_GRAPH}.dot
    -G Ninja
    # Use absolute path of PROJECT_DIR, because we change the current working
    # folder to ${BUILD_DIR}/${BUILD_TARGETS_GRAPH} when invoking CMake.
    -S "$(cd "${PROJECT_DIR}" >/dev/null 2>&1 && pwd)"
    -B ..
)


if [ "${BUILD_PLATFORM}" == "rpi4" ]; then
    CMAKE_PARAMS+=(
        -D RPI4_MEMORY="4096"
    )
fi


# If a build directory exists, check if we can just do a quicker rebuild based
# on the changes
if [[ -d ${BUILD_DIR} ]]; then
    # Run the tests in the subshell, wipe the build folder if the shell returns
    # an error.
    (
        cd ${BUILD_DIR}

        # If the build is invoked with different parameters as last time, then
        # we have to do a full rebuild. Note that we do not implement the
        # feature that a command line with no build arguments takes what was
        # stored in the argument file. It turned out this does not match the
        # common workflow. Usually, a command line is rarely typed in, but for
        # re-builds one just takes a command line from the shell's history
        # buffer. Thus, specifying no arguments is usually intended to
        # explicitly trigger a build with the default configuration.
        if [[ ! -e ${CMAKE_PARAMS_FILE} \
              || "$(< ${CMAKE_PARAMS_FILE})" != "${CMAKE_PARAMS[@]}" \
           ]]; then
            print_new_section "build parameters have changed: cleaning build dir"

            exit 1
        fi

        # If there are no build rules, then usually the build config failed
        # somewhere. Try again creating a build configuration. Starting with
        # CMake 3.18, "rules.ninja" is no longer in the root folder, but in the
        # subfolder "CMakeFiles". Hence, both locations are checked.
        if [[ ! -e rules.ninja && ! -e CMakeFiles/rules.ninja ]]; then
            print_new_section "build folder broken: cleaning build dir"
            exit 1
        fi

        exit 0
    ) || rm -rf ${BUILD_DIR}
fi

if [[ ! -d ${BUILD_DIR} ]]; then

    print_new_section "configure build ..."

    # Create the build workspace manually, so configuration parameters can be
    # stored there
    mkdir -p ${BUILD_DIR}
    echo "${CMAKE_PARAMS[@]}" > ${BUILD_DIR}/${CMAKE_PARAMS_FILE}
    (
        # Unfortunately, when CMake generates the build targets graph, a lot of
        # *.dot files are created in the current working folder. There is no
        # way to specify a custom sub folder for them. A workaround to avoid
        # polluting the build folder root is invoking CMake from a dedicated
        # sub folder.
        cd ${BUILD_DIR}
        mkdir ${BUILD_TARGETS_GRAPH}
        cd ${BUILD_TARGETS_GRAPH}
        cmake "${CMAKE_PARAMS[@]}"
        # Create a picture with the build targets graph.
        dot -Tsvg ${BUILD_TARGETS_GRAPH}.dot -o ../${BUILD_TARGETS_GRAPH}.svg
    )

    print_new_section "start clean build ..."
else
    print_new_section "start re-build ..."
fi

cmake --build ${BUILD_DIR} --target ${BUILD_TARGET}


echo "##------------------------------------------------------------------------------"
echo "## build successful, output in ${BUILD_DIR}"
echo "##=============================================================================="
