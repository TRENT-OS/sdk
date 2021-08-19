#!/bin/bash -eu

#-------------------------------------------------------------------------------
# ELF dumper script
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#
# This script creates a dump from an ELF file. It's using 'objdump' to extract
# the information.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
function print_usage_help()
{
    echo ""
    echo "ELF dumper script"
    echo ""
    echo "Usage:"
    echo "   -h | --help"
    echo "   -i <ELF file>"
    echo "   -c <CROSS_COMPILER_PREFIX>  (optional)"
    echo "   -o <dump file>  (optional, stdout will be used otherwise)"
    echo ""
}


#-------------------------------------------------------------------------------
function print_err()
{
    local MSG=$1
    echo "ERROR: ${MSG}" >&2
}


#-------------------------------------------------------------------------------
function stdout_or_file
{
    local DUMP_FILE=${1:-}

    # There are many ways to conditionally print to stdout or a file. The
    # advantage of this solution is, that it just needs a pipe and does not use
    # redirection, but just existing tools.
    if [ -z "${DUMP_FILE}" ]; then
        # print stdin to stdout
        cat
    else
        # dump stdin to a file
        sed -n "w ${DUMP_FILE}"
    fi
}


#-------------------------------------------------------------------------------
function do_elf_dump()
{
    ELF_FILE=$1

    # Print various headers (ELF file, private, sections). Besides 'objdump',
    # 'readelf' is another tools that can provide helpful information here.
    ${CROSS_COMPILER_PREFIX}objdump -fph "${ELF_FILE}"

    # Print the symbol table, sorted by addresses. The grep expression takes all
    # lines that start with 8 hex digits, which works fine for 32-bit and 64-bit
    # ELF files. Besides 'objdump', 'nm' is another tools that can provide
    # helpful information here.
    echo -e "\nSymbol Table:"
    ${CROSS_COMPILER_PREFIX}objdump -t "${ELF_FILE}" | \
        grep -E "^[0-9a-fA-F]{8}" | \
        sort
    echo ""

    # Print the disassembly intermixed with source code. This can fail if
    # 'objdump' does not support the ELF's target architecture. In this case an
    # error message is shown, but the script will not fail. The issue usually
    # happens if the wrong toolchain is used because 'CROSS_COMPILER_PREFIX' was
    # no set properly.
    ${CROSS_COMPILER_PREFIX}objdump -dS "${ELF_FILE}" 2>&1 || true
}


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

ELF_FILE=""
CROSS_COMPILER_PREFIX=""
LST_FILE=""

if [ $# -eq 0 ]; then
    print_err "missing parameters"
    print_usage_help
    exit 1
fi
while getopts ":hc:i:o: -l help" ARG; do
    case "${ARG}" in
        h|help)
            print_usage_help
            exit 0
            ;;
        c)
            CROSS_COMPILER_PREFIX=${OPTARG}
            ;;
        i)
            ELF_FILE=${OPTARG}
            ;;
        o)
            LST_FILE=${OPTARG}
            ;;
        \?)
            print_err "invalid parameter ${OPTARG}"
            ;;
    esac
done

if [ -z "${ELF_FILE}" ]; then
    print_err "no ELF file given"
    exit 1
fi

if [ ! -f "${ELF_FILE}" ]; then
    print_err "ELF file not found: ${ELF_FILE}"
    exit 1
fi

do_elf_dump "${ELF_FILE}" | stdout_or_file "${LST_FILE}"
