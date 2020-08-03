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


# no Proxy communication as default
CON_QEMU_UART_PROXY="-serial /dev/null"
if [[ -z "${1:-}" ]]; then
    echo "No QEMU/Proxy connection."
else
    PARAM_CON_QEMU=${1}
    shift

    case ${PARAM_CON_QEMU} in
        "PTY")
            # QEMU connects serial port to newly created PTY, "-S" makes it
            # freeze on startup to allow a host application to connect there
            echo "QEMU/Proxy connection via PTY"
            CON_QEMU_UART_PROXY="-S -serial pty"
            ;;

        "TCP")
            # QEMU waits on port 4444 for a connection, connects serial port to
            # it and then starts the system
            echo "QEMU/Proxy connection via TCP"
            CON_QEMU_UART_PROXY="-serial tcp:localhost:4444,server"
            ;;

        *)
            echo "ERROR: invalid conection type: ${PARAM_CON_QEMU}"
            exit 1
    esac
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
