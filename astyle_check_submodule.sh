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

echo "Execute $(basename $0) in: $(pwd)"

#-------------------------------------------------------------------------------
# Collect files to be analysed
#-------------------------------------------------------------------------------

# Will hold a list of files to be checked for style compliance.
FILES=()

case ${ARGUMENT} in

    "--modified")
        FILES=(
            # Find all added, changed, modified and renamed files compared with
            # the branch origin/master.
            $(git diff-index --cached --diff-filter=ACMR --ignore-submodules \
                  --name-only origin/master)
            # Find all modified and new files of the current submodule. This is
            # only relevant for local usage with un-committed changes.
            $(git ls-files --modified --others)
        )
        ;;

    "--all")
        FILES=(
            # Find all files of the current submodule.
            $(git ls-files)
            # Find all new files of the current submodule. This is only relevant
            # for local usage with un-committed changes.
            $(git ls-files --others)
        )
        ;;

    *)
        FILES=( $@ )
        ;;

esac

# Sort the list and remove any duplicates, exclude all files in "3rdParty/"
# folders and pick only source code files for style analysis.
FILES=(
    $( printf -- '%s\n' "${FILES[@]}" \
       | sort -u \
       | grep -v '3rdParty\/' \
       | grep -i '\.c$\|\.h$\|\.cpp$\|\.hpp$' \
    )
)

#-------------------------------------------------------------------------------
# Analyse files with astyle
#-------------------------------------------------------------------------------
RETVAL=0

SDK_DIR=$(realpath $(dirname $0))

# Source submodule options to get ASTYLE_OPTIONS_SUBMODULE. Ensure that the
# variable exist and is empty by default, so we don't have to worry later if the
# local config did not set it.
ASTYLE_OPTIONS_SUBMODULE=""
LOCAL_CONFIG_FILE=astyle_prepare_submodule.sh
if [ ! -f ${LOCAL_CONFIG_FILE} ]; then
    true # need a dummy command here, uncomment the line below for debug
    # echo "no local config"
else
    source ./${LOCAL_CONFIG_FILE}
    if [ ! -z "${ASTYLE_OPTIONS_SUBMODULE}" ]; then
        echo "using local astyle config"
    else
        true # need a dummy command here, uncomment the line below for debug
        # echo "found local config, but ASTYLE_OPTIONS_SUBMODULE not set"
    fi
fi

for IN_FILE in ${FILES[@]}; do

    OUT_FILE="${IN_FILE}.astyle"

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
