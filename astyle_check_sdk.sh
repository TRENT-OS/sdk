#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# This script will search for astyle_check.sh scripts in all sub-folders of the
# current working directory and execute them.
#
# Those astyle_check.sh scripts should be added to all relevant submodules. They
# should generate *.astyle files if there are any astyle issues.
#
# By checking if *.astyle files exist this script determines if there is at
# least one astyle issue and returns an error code that can be used by CI.
#
# NOTE: Generated *.astyle files are only removed prior to the execution (to
# produce a reliable result) but not afterwards (to support fixing the issues).
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Show usage information
#-------------------------------------------------------------------------------
ARGUMENT=${1:-}

if [ "${ARGUMENT}" = "--help" ]; then

    USAGE_INFO="Usage: $(basename $0) [--help | --all | --modified]
    --help      Show usage information.
    --all       Call astyle scripts with --all.
    --modified  Call astyle scripts with --modified which is the default if no
                argument is passed."

    echo "${USAGE_INFO}"
    exit 0

fi

echo "---"
echo "Execute $(basename $0) in:"
echo $(pwd)
echo "-"

#-------------------------------------------------------------------------------
# Find and execute astyle scripts
#-------------------------------------------------------------------------------
ASTYLE_SCRIPT_ARGUMENT="--modified"

if [ "${ARGUMENT}" = "--all" ]; then
    ASTYLE_SCRIPT_ARGUMENT="--all"
fi

# remove previously existing astyle files
find . -name '*.astyle' -exec rm -v {} \;

# find and execute astyle checks
find . -name 'astyle_check.sh' -execdir {} ${ASTYLE_SCRIPT_ARGUMENT} \;

# find all created astyle files
FILES=$(find . -name '*.astyle')

echo "-"

#-------------------------------------------------------------------------------
# Check if any astyle files have been created
#-------------------------------------------------------------------------------
if [ ! -z "${FILES}" ]; then
    echo "ERROR: astyle issues found."
    echo "-"
    echo "Check the following files:"

    for FILE in ${FILES}; do
        SRC_FILE=${FILE%.astyle} # get file name without astyle suffix
        echo "  ${SRC_FILE}"
    done

    echo "---"

    exit 1 # error
fi

echo "INFO: No astyle issue found."
echo "---"

exit 0 # success
