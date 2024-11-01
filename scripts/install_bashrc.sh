#!/bin/bash -eu

#-------------------------------------------------------------------------------
# Copyright (C) 2020-2024, HENSOLDT Cyber GmbH
# 
# SPDX-License-Identifier: GPL-2.0-or-later
#
# For commercial licensing, contact: info.cyber@hensoldt.net
#-------------------------------------------------------------------------------

# get the directory the script is located in
DIR=`dirname "$(readlink -f "$0")"`

# check if it's already installed
CHECK_INSTALL=`grep TRENTOS ~/.bashrc`
if [ ! -z "${CHECK_INSTALL}" ]
	then
		echo "Commands already exist in .bashrc" 
		exit 0
fi

# apply newline to be sure we don't append to an existing line
echo "" >> ~/.bashrc
echo "" >> ~/.bashrc

# install our functions in the current users .bashrc file
cat ${DIR}/bash_functions.def >> ~/.bashrc
