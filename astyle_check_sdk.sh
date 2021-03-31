#!/bin/bash -ue

#-------------------------------------------------------------------------------
# Copyright (C) 2021, HENSOLDT Cyber GmbH
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# This script will search for astyle_prepare_submodule.sh scripts in all sub-
# folders of the working directory and execute the astyle_check_submodule.sh
# script there.
#
# To add a submodule to the astyle check the astyle_prepare_submodule.sh script
# has to be added to the submodule.
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
ARGUMENT=${1:---modified}


if [ "${ARGUMENT}" = "--help" ] || \
    [ "${ARGUMENT}" != "--all" ] && \
    [ "${ARGUMENT}" != "--modified" ]; then

    USAGE_INFO="Usage: $(basename $0) [--help | --all | --modified]
    --help      Show usage information.
    --all       Call astyle scripts with --all.
    --modified  Call astyle scripts with --modified which is the default if no
                argument is passed."

    echo "${USAGE_INFO}"
    exit 0
fi

#-------------------------------------------------------------------------------
# Run style check in a folder.
#-------------------------------------------------------------------------------
function run_astyle_check()
{
    local FOLDER=$1
     # Need to make it an absolute path, as we change the current working dir.
    local ASTYLE_DEFAULTS_FILE=$(realpath $2)
    # Optional parameter
    local ARGUMENT=${3:-}
    # Get rid of the first two parameters. If ARGUMENT does not match one from
    # the values checks below we assume all additional parameters are file names
    # given explicitly to be checked.
    shift 2

    # Run check in a sub shell, since we change the current working directory.
    (
        cd ${FOLDER}

        # Source submodule options to get ASTYLE_OPTIONS_SUBMODULE. Ensure that
        # the variable exist and is empty by default, so we don't have to worry
        # later if the local config did not set it.
        local ASTYLE_OPTIONS_SUBMODULE=""
        local LOCAL_CONFIG_FILE=astyle_prepare_submodule.sh
        if [ ! -f ${LOCAL_CONFIG_FILE} ]; then
            echo "checking: ${FOLDER}"
        else
            # Ensure we source this with the current working directory set to
            # the folder this is in, so any code in this file find the proper
            # environment.
            source ./${LOCAL_CONFIG_FILE}
            if [ -z "${ASTYLE_OPTIONS_SUBMODULE}" ]; then
                # Seems we have many config files that don't set anything and
                # could be removed.
                # echo "checking (local config empty): ${FOLDER}"
                echo "checking: ${FOLDER}" #
            else
                echo "checking (with local config): ${FOLDER}"
            fi
        fi

        case ${ARGUMENT} in

            "--modified")
                FILES=(
                    # Find all added, changed, modified and renamed files
                    # compared with the branch origin/master.
                    $(git diff-index --cached --diff-filter=ACMR \
                          --ignore-submodules --name-only origin/master)
                    # Find all modified and new files of the current submodule.
                    # This is only relevant for local usage with un-committed
                    # changes.
                    $(git ls-files --modified --others)
                )
                ;;

            "--all")
                FILES=(
                    # Find all files of the current submodule.
                    $(git ls-files)
                    # Find all new files of the current submodule. This is only
                    # relevant for local usage with un-committed changes.
                    $(git ls-files --others)
                )
                ;;

            *)
                # Take all remaining parameters as file names. This works
                # because above we've thrown away the parameters that control
                # the behavior of this whole function.
                FILES=( "$@" )
                ;;

        esac

        # "3rdParty/" folders, pick only source code files for style analysis.
        # grep will return an error if it found nothing, we have to swallow this
        # error and just end up with an empty list then.
        FILES=(
            $( printf -- '%s\n' "${FILES[@]}" \
               | sort -u \
               | grep -v '3rdParty\/' \
               | grep -i '\.c$\|\.h$\|\.cpp$\|\.hpp$' \
               || true
            )
        )

        # Analyse each file
        for IN_FILE in "${FILES[@]}"; do

            OUT_FILE="${IN_FILE}.astyle"

            # Run astyle with project/default options file on IN_FILE and create
            # OUT_FILE.
            astyle \
                ${ASTYLE_OPTIONS_SUBMODULE} \
                --options=${ASTYLE_DEFAULTS_FILE} \
                <${IN_FILE} \
                >${OUT_FILE} \

            # Compare files to detect if there are style issues. Delete the
            # astyle file if there is no difference, otherwise print the file
            # name. Since this runs in "bash -e" mode (exit on error), this
            # "swallows" the dif return code and yields the return code from
            # "rm" or "echo", which is 0 unless there is a serious problem.
            diff ${IN_FILE} ${OUT_FILE} > /dev/null \
                && rm ${OUT_FILE} \
                || echo "  ${IN_FILE}"

        done
    )
}

#-------------------------------------------------------------------------------
# Find and execute astyle scripts
#-------------------------------------------------------------------------------

echo "Execute $(basename $0) in: $(pwd)"

# We assume this script is located in the SDK root folder
SDK_DIR=$(dirname $0)

# remove previously existing astyle files
find . -name '*.astyle' -exec rm -v {} \;

# find submodules with prepare submodule script
PROJECT_LIST=$(find . -name 'astyle_prepare_submodule.sh')

# run astyle check in each project directory
for PROJECT in ${PROJECT_LIST}; do
    run_astyle_check \
        "$(dirname ${PROJECT})" \
        "${SDK_DIR}/astyle_options_default" \
        ${ARGUMENT}
done

# Check if any astyle files have been created
FILES=$(find . -name '*.astyle')

if [ ! -z "${FILES}" ]; then
    echo "ERROR: astyle issue found, see *.astyle file for proposed fix"
    exit 1 # error
fi

echo "INFO: No astyle issue found."

exit 0 # success
