#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# This script will run astyle with a set of defined options on a list of files.
#
# The source files can be passed as arguments. Otherwise the script uses git to
# find either all new or modified source files (default or --modified) or all
# source files (--all) of the submodule it is located in. Since the git commands
# have to be executed within the submodule the script changes the working
# directory.
#
# The astyle analysis will generate an *.astyle file for each input file. If
# astyle did some correction this means that an astyle issue was found. In this
# case the *.astyle file is kept, otherwise the *.astyle file is removed.
#
# If there is at least one astyle issue, the script will return an error code.
#-------------------------------------------------------------------------------

cd "$(dirname "$0")"

#-------------------------------------------------------------------------------
# Show usage information
#-------------------------------------------------------------------------------
ARGUMENT=${1:-}

if [ "${ARGUMENT}" = "--help" ]; then

    USAGE_INFO="Usage: $(basename $0) [--help | --all | --modified | [FILE]...]
    --help      Show usage information.
    --all       Analyse all source files in current submodule.
    --modified  Analyse new or modified source files in current submodule which
                is the default if no argument is passed.
    FILEs       List of FILEs to be analyzed."

    echo "${USAGE_INFO}"
    exit 0

fi

echo "Execute $(basename $0) in:"
echo $(pwd)

#-------------------------------------------------------------------------------
# Define astyle command and options
#-------------------------------------------------------------------------------
ASTYLE_CMD=astyle

ASTYLE_OPTIONS="--suffix=none \
                --style=allman \
                --indent=spaces=4 \
                --indent-classes \
                --indent-namespaces \
                --pad-oper \
                --pad-header \
                --pad-comma \
                --add-brackets \
                --align-pointer=type \
                --align-reference=name \
                --min-conditional-indent=0 \
                --lineend=linux \
                --max-code-length=80 \
                --max-continuation-indent=60"

#-------------------------------------------------------------------------------
# Check if astyle is available
#-------------------------------------------------------------------------------
case $(${ASTYLE_CMD} --version 2> /dev/null) in

  "Artistic Style Version"*)
      ;;

  *)
      echo "ERROR: ${ASTYLE_CMD} was not found."
      exit 1
      ;;

esac

#-------------------------------------------------------------------------------
# Collect files to be analysed
#-------------------------------------------------------------------------------
case ${ARGUMENT} in

    "" | "--modified")
        # Find all added, changed, modified and renamed files compared with the
        # branch origin/master.
        FILES=$(git diff-index --cached --diff-filter=ACMR --ignore-submodules \
            --name-only origin/master)

        # Insert newline.
        FILES+=$'\n'

        # Find all modified and new files of the current submodule.
        # NOTE: This is only relevant for local usage with un-committed changes.
        FILES+=$(git ls-files --modified --others)
        ;;

    "--all")
        # Find all files of the current submodule.
        FILES=$(git ls-files)

        # Insert newline.
        FILES+=$'\n'

        # Find all new files of the current submodule.
        # NOTE: This is only relevant for local usage with un-committed changes.
        FILES+=$(git ls-files --others)
        ;;

    *)
        FILES=$@
        ;;

esac

# Filter for source code files.
FILES=$(echo ${FILES} | xargs -n1 | grep -i '\.c$\|\.cpp$\|\.hpp$\|\.h$')

# Sort and remove duplicates.
FILES=$(echo ${FILES} | xargs -n1 | sort -u)

#-------------------------------------------------------------------------------
# Analyse files with astyle
#-------------------------------------------------------------------------------
RETVAL=0

for IN_FILE in ${FILES}; do

    OUT_FILE="${IN_FILE}.astyle"

    # run astyle on infile and create outfile
    ${ASTYLE_CMD} ${ASTYLE_OPTIONS} <${IN_FILE} >${OUT_FILE}

    # compare files to detect issues (and avoid exit on command error)
    ISSUE_FOUND=false
    diff ${IN_FILE} ${OUT_FILE} > /dev/null || ISSUE_FOUND=true

    if [ ${ISSUE_FOUND} = true ]; then

        # return an error if at least one difference / issue was found
        RETVAL=1
        echo "astyle issue: ${OUT_FILE}"

    else

        # delete outfile if no difference / issue was found
        rm ${OUT_FILE}

    fi

done

exit $RETVAL
