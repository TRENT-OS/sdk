#!/bin/bash -eu

#-------------------------------------------------------------------------------
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

if [[ -z "${1:-}" ]]; then
    echo "ERROR: missing test image"
    exit 1
fi
SYSTEM_IMAGE=${1}
shift
if [[ ! -e "${SYSTEM_IMAGE}" ]]; then
    echo "system image not found: ${SYSTEM_IMAGE}"
    exit 1
fi

PARAM_CON_QEMU=${1:-}
if [[ ! -z "${1:-}" ]]; then
    shift
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
    -kernel ${SYSTEM_IMAGE}
)

# run QEMU showing command line
set -x
qemu-system-arm ${QEMU_PARAMS[@]}
