#!/bin/bash -uex

bamboo_GIT_HTTPS_USER=user
bamboo_GIT_HTTPS_SECRET_TOKEN=token/42

#
# https://stackoverflow.com/questions/28346387/proper-way-to-release-in-git-with-submodules
#
#
#
#(
#  cd sandbox
#  # seems this fails somewhere....
#  git ls-files --recurse-submodules | tar -cvjf ../archive.bz2 -T-
#)
#

SERVER=bitbucket.app.hensoldt.net

#BRANCH=integration
BRANCH=SEOS-000_bamboo_ci

#echo "GIT_HTTPS_SECRET_TOKEN: <${bamboo_GIT_HTTPS_SECRET_TOKEN}>"
#echo "GIT_HTTPS_USER: <${bamboo_GIT_HTTPS_USER}>"

# Notes:
#   - usually, the token is vlid for a year only
#   - the token may contains special chars, so it needs ot be urlencoded
#        !   #   $   &   '   (   )   *   +   ,   /   :   ;   =   ?   @   [   ]
#        %21 %23 %24 %26 %27 %28 %29 %2A %2B %2C %2F %3A %3B %3D %3F %40 %5B %5D
function do_urlencode()
{
  # (ab-)use curl with an empty url and remove the initial "/?" from the output,
  # because it is a relative URL with a query string.
  curl -Gso /dev/null -w %{url_effective} --data-urlencode "$1" "" | cut -c 3-
}

# Unfortunately, Bamboo does not support GIT submodules with relative
# paths, so we have to run the checkout manually. Using 4 parallel jobs
# it a random choice that turned out to work well.
function do_checkout()
{
    local REPO=$1
    local BRANCH=$2
    local DST=$3

    echo $(do_urlencode ${bamboo_GIT_HTTPS_SECRET_TOKEN})

    local REPO_URL=https://${bamboo_GIT_HTTPS_USER}:$(do_urlencode ${bamboo_GIT_HTTPS_SECRET_TOKEN})@${SERVER}/scm/${REPO}
    #REPO_URL=ssh://git@${SERVER}/${REPO}
    echo git clone --jobs 4 --recursive --branch ${BRANCH} ${REPO_URL} ${DST}
}

do_checkout seos/sandbox.git ${BRANCH} src/sdk
# some statistics
git -C src/sdk status
du -sh src/sdk
du -sh

# ToDo: check out SDK demos
#   process_yaml_config "scm-src/test-cfg.yaml" ${BRANCH}
src/sdk/.bamboo-specs/process_yaml_cfg.py -C scm-src --list-demo-repos | while read demo_repo ; do
   do_checkout ${demo_repo} ${BRANCH} src/demos/${demo_repo#*/}
done
