#!/bin/bash

(
    cd "$(dirname "$0")"

    echo "---"
    echo "Execute astyle check for SDK"

    # remove previously existing astyle files
    find . -name '*.astyle' -exec rm -v {} \;

    # find and execute astyle checks
    find . -name 'astyle_check.sh' -execdir {} \;

    # find all created astyle files
    FILES=$(find . -name '*.astyle')

    echo "-"

    # check if any astyle files have been created
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
)
