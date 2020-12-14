#!/bin/bash

#-------------------------------------------------------------------------------
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

WORDDIR=`pwd`

cppcheck --project=build/compile_commands.json --output-file=cppcheck_output.txt \
    -i "${WORDDIR}/src/sdk/libs/os_network_stack/3rdParty/" \
    -i "${WORDDIR}/src/sdk/sdk-sel4-camkes/"

# CMake always builds some libraries which expect a configuration header, which isn't
# provided by the test system if it doesn't use that library. This filters out the error
# messages cppcheck generates for that case.
excluded=(
    \#error
)

# Print the file so we have it in the Jenkins log
echo -e "\n CPPCHECK OUTPUT \n"
cat "cppcheck_output.txt"

# remove all lines from the output file which match elements in the
# exclusion list

grep -v `printf '%s '"${excluded[@]/#/-e }"` "cppcheck_output.txt" > "cppcheck_output.txt.out"


# if there still are warnings left, fail the stage

if [[ $(wc -l < "cppcheck_output.txt.out") -gt 0 ]]; then
    exit 1
fi

exit 0