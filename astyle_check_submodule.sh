#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# This script will run astyle with the defined astyle options.
#
# Each submodule to be checked contains a astyle_prepare_submodule.sh script
# that sets a variable ASTYLE_OPTIONS_SUBMODULE. The variable is usually empty
# but can overwrite astyle options defined in the default options file of the
# sandbox (astyle_options_default).
#
# This script uses git to find either new or modified source files (default or
# --modified) or all source files (--all) of the submodule it is located
# in. Alternatively source files can be passed as arguments. This script has to
# be executed within the same folder the prepare submodule script is located in.
#
# The astyle analysis will generate an *.astyle file for each input file. If
# astyle did some correction this means that an astyle issue was found. In this
# case the *.astyle file is kept, otherwise the *.astyle file is removed.
#
# If there is at least one astyle issue, the script will return an error code.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Show usage information
#-------------------------------------------------------------------------------
ARGUMENT=${1:---modified}

if [ "${ARGUMENT}" = "--help" ]; then

    USAGE_INFO="Usage: $(basename $0) [--help | --all | --modified | FILEs]
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
# Check if astyle is available
#-------------------------------------------------------------------------------
case $(astyle --version 2> /dev/null) in

  "Artistic Style Version"*)
      ;;

  *)
      echo "ERROR: astyle was not found."
      exit 1
      ;;

esac

#-------------------------------------------------------------------------------
# Collect files to be analysed
#-------------------------------------------------------------------------------
case ${ARGUMENT} in

    "--modified")
        # Find all added, changed, modified and renamed files compared with the
        # branch origin/master.
        FILES=$(git diff-index --cached --diff-filter=ACMR --ignore-submodules \
            --name-only origin/master)

        # Insert newline.
        FILES+='\n'

        # Find all modified and new files of the current submodule.
        # NOTE: This is only relevant for local usage with un-committed changes.
        FILES+=$(git ls-files --modified --others)
        ;;

    "--all")
        # Find all files of the current submodule.
        FILES=$(git ls-files)

        # Insert newline.
        FILES+='\n'

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

# Exclude alle files below a folder "3rdParty/".
FILES=$(echo ${FILES} | xargs -n1 | grep -v '3rdParty\/')

#-------------------------------------------------------------------------------
# Analyse files with astyle
#-------------------------------------------------------------------------------
RETVAL=0

SDK_DIR=$(realpath $(dirname $0))

for IN_FILE in ${FILES}; do

    OUT_FILE="${IN_FILE}.astyle"

    # source submodule options ASTYLE_OPTIONS_SUBMODULE
    . ./astyle_prepare_submodule.sh

    # run astyle with project/default options file on infile and create outfile
    astyle ${ASTYLE_OPTIONS_SUBMODULE} \
        --options=${SDK_DIR}/astyle_options_default \
        <${IN_FILE} \
        >${OUT_FILE}

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
