#!/bin/bash

(
    cd "$(dirname "$0")"

    # remove previously existing astyle files
    find . -name '*.astyle' -exec rm -v {} \;

    # find and execute astyle checks
    find . -name 'astyle_check.sh' -execdir {} \;

    # find all created astyle files
    FILES=$(find . -name '*.astyle')

    # check if any astyle files have been created
    if [ ! -z "${FILES}" ]; then
        echo "ERROR: AStyle issues found."
        echo "Check the following files:"

        for FILE in ${FILES}; do
            echo "  ${FILE}"
        done

        exit 1 # error
    fi

    exit 0 # success
)
