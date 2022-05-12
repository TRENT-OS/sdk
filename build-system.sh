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
# NOTE: The environment variable ENABLE_ANALYSIS has to be set to "ON" if the
#       script is used for an analysis with the axivion suite.
#
# NOTE: The environment variable BUILD_TARGET might be used to specify an
#       individual CMake build target. Usually, this is used for the analysis
#       with the axivion suite. If not set, "all" will be used for regular
#       builds per default.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# There is a race condition in the Jenkins docker agent plugin that in some
# circumstances leads to the build script being executed before fixuid
# finishes updating the runtime environment.
# https://issues.jenkins.io/browse/JENKINS-54389

# As a hard requirement for this script, it needs to be executed in a
# container whose entrypoint script calls fixuid.

# Wait until fixuid finished setting up the environment
until [ -f /run/fixuid.ran ]
do
    echo "Waiting for fixuid to finish."
    sleep 1
done

# In case the race condition happened, the shell this script runs in spawned
# before fixuid could set up the environment variable(s). They have to be set
# manually here.
export HOME=/home/user

#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# this script is located in the SDK folder
export OS_SDK_PATH="${SCRIPT_DIR}"

# read parameters
OS_PROJECT_DIR=$1
BUILD_PLATFORM=$2
BUILD_DIR=$3
shift 3
# all remaining parameters will be passed to CMake
BUILD_ARGS=("$@")
CMAKE_PARAMS_FILE=cmake_params.txt

#-------------------------------------------------------------------------------

# Check if analysis is enabled by environment variable (default: OFF).
ENABLE_ANALYSIS=${ENABLE_ANALYSIS:-OFF}

# Check if an individual CMake build target is set in the environment variable,
# for example used for analysis (default: all).
BUILD_TARGET=${BUILD_TARGET:-all}

#-------------------------------------------------------------------------------

echo ""
echo "##=============================================================================="
echo "## Project:   ${OS_PROJECT_DIR}"
echo "## Platform:  ${BUILD_PLATFORM}"
echo "## Output:    ${BUILD_DIR}"

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
    rockpro64 |\
    rpi4 |\
    tx1 |\
    tx2 |\
    zynqmp | zynqmp-zcu102 | zynqmp-ultra96 | ultra96 )
        BUILD_ARCH=aarch64
        ;;
    #-------------------------------------
    ariane |\
    hifive )
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
        echo ""
        echo "##"
        echo "## ERROR: invalid platform '${BUILD_PLATFORM}'"
        echo "##"
        exit 1
        ;;
esac

case "${BUILD_ARCH}" in
    aarch32)
        CMAKE_PARAMS_PLATFORM+=( -D AARCH32=TRUE )
        CROSS_COMPILER_PREFIX=arm-linux-gnueabi-
        ;;
    aarch64)
        CMAKE_PARAMS_PLATFORM+=( -D AARCH64=TRUE )
        CROSS_COMPILER_PREFIX=aarch64-linux-gnu-
        ;;
    riscv32)
        CMAKE_PARAMS_PLATFORM+=( -D RISCV32=TRUE )
        # 64-bit toolchain can build 32 targets also
        CROSS_COMPILER_PREFIX=riscv64-unknown-linux-gnu-
        ;;
    riscv64)
        CMAKE_PARAMS_PLATFORM+=( -D RISCV64=TRUE )
        CROSS_COMPILER_PREFIX=riscv64-unknown-linux-gnu-
        ;;

    pc99 | ia32 | x86_64)
        # 64-bit toolchain can build 32 targets also
        CROSS_COMPILER_PREFIX=x86_64-linux-gnu-
        ;;
    *)
        echo ""
        echo "##"
        echo "## ERROR: invalid architecture '${BUILD_ARCH}'"
        echo "##"
        exit 1
        ;;
esac

# Set toolchain file for regular builds
TOOLCHAIN_FILE="${OS_SDK_PATH}/sdk-sel4-camkes/kernel/gcc.cmake"

if [[ ${ENABLE_ANALYSIS} == "ON" ]]; then
    # Set toolchain file for axivion suite if analysis enabled
    TOOLCHAIN_FILE="${OS_SDK_PATH}/scripts/axivion/axivion-sel4-toolchain.cmake"
fi

# Set CMake parameters
CMAKE_PARAMS+=(
    # CMake settings
    -D CROSS_COMPILER_PREFIX=${CROSS_COMPILER_PREFIX}
    -D CMAKE_TOOLCHAIN_FILE:FILEPATH=${TOOLCHAIN_FILE}
    # seL4 build system settings
    -D PLATFORM=${BUILD_PLATFORM}
    "${CMAKE_PARAMS_PLATFORM[@]}"
    -D KernelVerificationBuild=OFF
    # SEL4_CACHE_DIR is a binary cache. There are some binaries (currently
    # musllibc and capDL-tool) that are project agnostic, so we don't have
    # to rebuild them every time. This reduces the build time a lot.
    -D SEL4_CACHE_DIR:PATH=cache-${BUILD_PLATFORM}
    # Location of the OS project to be built. Since we will change the current
    # working directory, we have to ensure this is an absolute path.
    -D OS_PROJECT_DIR:PATH=$(realpath ${OS_PROJECT_DIR})
    "${BUILD_ARGS[@]}"
    -G Ninja
    -S ${OS_SDK_PATH}
    -B ${BUILD_DIR}
)


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
            echo "##------------------------------------------------------------------------------"
            echo "## build parameters have changed: cleaning build dir"
            echo "##------------------------------------------------------------------------------"
            exit 1
        fi

        # If there are no build rules, then usually the build config failed
        # somewhere. Try again creating a build configuration. Starting with
        # CMake 3.18, "rules.ninja" is no longer in the root folder, but in the
        # subfolder "CMakeFiles". Hence, both locations are checked.
        if [[ ! -e rules.ninja && ! -e CMakeFiles/rules.ninja ]]; then
            echo "##------------------------------------------------------------------------------"
            echo "## build folder broken: cleaning build dir"
            echo "##------------------------------------------------------------------------------"
            exit 1
        fi

        exit 0
    ) || rm -rf ${BUILD_DIR}
fi

if [[ ! -d ${BUILD_DIR} ]]; then

    echo "##------------------------------------------------------------------------------"
    echo "## configure build ..."
    echo "##------------------------------------------------------------------------------"

    if [[ ${ENABLE_ANALYSIS} == "ON" ]]; then
        # Prepare axivion suite for CMake config
        export COMPILE_ONLY=yes
        unset COMPILE_ONLYIR
    fi

    # Create the build workspace manually, so configuration parameters can be
    # stored there
    mkdir -p ${BUILD_DIR}
    echo "${CMAKE_PARAMS[@]}" > ${BUILD_DIR}/${CMAKE_PARAMS_FILE}
    (
        set -x
        cmake ${CMAKE_PARAMS[@]}
    )

    # CMake must run twice, so the config settings propagate properly. The
    # first runs populates the cache and the second run will find the correct
    # settings in the cache to set up the build.
    # Create a dependency graph with all build targets also. Since this creates
    # many *.dot files, the re-run is invoked from a subfolder and just the
    # final picture is placed in the root folder.
    # root folder.
    echo "##------------------------------------------------------------------------------"
    echo "## re-run configure build ..."
    echo "##------------------------------------------------------------------------------"
    BUILD_TARGETS_GRAPH=build-targets-graph
    mkdir -p ${BUILD_DIR}/${BUILD_TARGETS_GRAPH}
    (
        cd ${BUILD_DIR}/${BUILD_TARGETS_GRAPH}
        cmake --graphviz=${BUILD_TARGETS_GRAPH}.dot ..
        dot -Tsvg ${BUILD_TARGETS_GRAPH}.dot -o ../${BUILD_TARGETS_GRAPH}.svg
    )

    echo "##------------------------------------------------------------------------------"
    echo "## start clean build ..."
    echo "##------------------------------------------------------------------------------"
else
    echo "##------------------------------------------------------------------------------"
    echo "## start re-build ..."
    echo "##------------------------------------------------------------------------------"
fi


if [[ ${ENABLE_ANALYSIS} == "ON" ]]; then
    # Prepare axivion suite for CMake build
    unset COMPILE_ONLY
    export COMPILE_ONLYIR=yes
fi

cmake --build ${BUILD_DIR} --target ${BUILD_TARGET}


echo "##------------------------------------------------------------------------------"
echo "## build successful, output in ${BUILD_DIR}"
echo "##=============================================================================="
