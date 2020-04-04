#!/bin/bash -ue

#-------------------------------------------------------------------------------
#
# Publish documentation and reports to web server
#
# Copyright (C) 2019, Hensoldt Cyber GmbH
#
#-------------------------------------------------------------------------------

DOC_ROOT=/var/www

BRANCH_NAME=$1
DOC_DIR=${DOC_ROOT}/seos_sdk/${BRANCH_NAME}

rm -rf ${DOC_DIR}
mkdir -p ${DOC_DIR}

mv sdk-package/pkg/doc ${DOC_DIR}/
