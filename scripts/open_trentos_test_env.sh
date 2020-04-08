#!/bin/bash -eu

#-------------------------------------------------------------------------------
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

# get the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# load function definitions into current bash
source ${SCRIPT_DIR}/bash_functions.def

# execute trentos_test and pass all the arguments we received
open_trentos_test_env "$@"
