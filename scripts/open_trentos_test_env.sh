#!/bin/bash -eu

#-------------------------------------------------------------------------------
#
# Copyright (C) 2020, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

# get the directory the script is located in
DIR=`dirname "$(readlink -f "$0")"`

# load function definitions into current bash
source ${DIR}/bash_functions.def

# execute trentos_test and pass all the arguments we received
open_trentos_test_env "$@"
