#!/bin/bash -ue

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

ASTYLE_SETTINGS_LINUX_USER_SPACE=(
    --suffix=none
    --style=allman
    --indent=spaces=4
    --indent-classes
    --indent-namespaces
    --pad-oper
    --pad-header
    --pad-comma
    --add-brackets
    --align-pointer=type
    --align-reference=name
    --min-conditional-indent=0
    --lineend=linux
    --max-code-length=80
    --max-continuation-indent=60
)

ASTYLE_SETTINGS_LINUX_KERNEL_SPACE=(
    --style=1tbs
    --indent=tab
    --align-pointer=name
    --add-brackets
    --max-code-length=80
)

ASTYLE_PARAMETERS=${ASTYLE_SETTINGS_LINUX_USER_SPACE[@]}

if [ ! -z "${1:-}" ] && [ "${1:-}" = "--help" ]; then
    echo "If you run the script without arguments then the files which are new or modified since the creation of the branch will be checked."
    echo "Otherwise you can use the argument list of this script to specify the files you want to check."
    echo "e.g.: ./astyle_check.sh \`git status -s | cut -c4- | grep -i '\.c$\|\.cpp$\|\.hpp$\|\.h$'\`"
    exit 0
fi



cd ${SCRIPT_DIR}

FILES=$@

if [ -z "${FILES}" ]; then

    # check any modified or new files. Note that there are many ways to get a
    # list of changes, but all have subtle differents. We are interested in
    # files from the current module only and don't care about submodules, so
    # the current command works good enough. If we need the changed submodules
    # included also then "git status --porcelain=v1 | cut -c4-" is the
    # better choice. However, there is no command line option available that
    # dives into the submodule and list the actualy files with changes.
    FILES=$(git ls-files --modified --others | grep -i '\.c$\|\.cpp$\|\.hpp$\|\.h$' || true)

    # check all file that have been create or modified since branch creation
    FILES+=" "$(git diff-index --diff-filter=ACMR --name-only -r --cached origin/master | grep -i '\.c$\|\.cpp$\|\.hpp$\|\.h$' || true)

fi

# sort and remove duplicates
FILES=$(echo ${FILES} | xargs -n1 | sort -u | xargs)

ASTYLE_FAILURES=()
for file in ${FILES}; do
    ASTYLE_OUT_FILE="${file}.astyle"

    astyle ${ASTYLE_PARAMETERS} <${file} >${ASTYLE_OUT_FILE}
    # in "bash -ue" mode "expr && RET=$? || RET=$?" must be used
    cmp --silent ${file} ${ASTYLE_OUT_FILE} && RET=$? || RET=$?
    if [ ${RET} -ne 0 ]; then
        ASTYLE_FAILURES+=(${file})
        continue
    fi
    # everything ok, delete astyle file
    rm ${ASTYLE_OUT_FILE}
done

if [ ${#ASTYLE_FAILURES[@]} -ne 0 ]; then
    echo "WARNING: astyle compliance failures found in these files"
    for file in ${ASTYLE_FAILURES[@]}; do
        echo "  ${file}"
    done
    exit 1
fi
