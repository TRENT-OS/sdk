#!/bin/bash -eu

#-------------------------------------------------------------------------------
#
# Build script
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

if [[ -z "${1:-}" ]]; then
    echo "ERROR: missing test image"
    exit 1
fi
TEST_NAME=${1}
shift

PARAM_CON_QEMU=${1:-}
if [[ ! -z "${1:-}" ]]; then
    shift
fi


#-------------------------------------------------------------------------------
# test image

if [ -z "${TEST_NAME}" ]; then
    echo "ERROR: missing test name"
    exit 1
fi

# default is the zynq7000 platform and debug build
PLATFORM=zynq7000
BUILD_MODE=Debug
IMAGE_PATH=build-${PLATFORM}-${BUILD_MODE}-${TEST_NAME}/images/capdl-loader-image-arm-${PLATFORM}
if [ ! -f ${IMAGE_PATH} ]; then
    echo "ERROR: missing test image ${IMAGE_PATH}"
    exit 1
fi


#-------------------------------------------------------------------------------
# QEMU serial port 0 connection

# no Proxy communication as default
CON_QEMU_UART_PROXY="-serial /dev/null"

if [[ -z "${PARAM_CON_QEMU}" ]]; then
    echo "No QEMU connection was set."

elif [[ ${PARAM_CON_QEMU} == "PTY" ]]; then
    # QEMU connects serial port to newly created PTY, "-S" makes it freeze on
    # startup to allow a host application to connect there
    CON_QEMU_UART_PROXY="-S -serial pty"

elif [[ ${PARAM_CON_QEMU} == "TCP" ]]; then
    # QEMU waits on port 4444 for a connection, connects serial port to it and
    # then starts the system
    CON_QEMU_UART_PROXY="-serial tcp:localhost:4444,server"

else
    echo "ERROR: invalid conection type: ${PARAM_CON_QEMU}"
    exit 1

fi


#-------------------------------------------------------------------------------
# run QEMU

QEMU_PARAMS=(
    -machine xilinx-zynq-a9
    -m size=512M
    -nographic
    ${CON_QEMU_UART_PROXY} # serial port 0 is used for Proxy connection
    -serial mon:stdio      # serial port 1 is used for console
    -kernel ${IMAGE_PATH}
)

qemu-system-arm ${QEMU_PARAMS[@]}
