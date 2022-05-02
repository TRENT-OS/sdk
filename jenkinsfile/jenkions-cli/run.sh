#!/bin/bash -ue

SCRIPT_DIR=$(cd `dirname $0` && pwd)

SEOS_TEST_DIR=${SCRIPT_DIR}/../..

if [ ! -e ${SEOS_TEST_DIR}/test-cfg.yaml ]; then
    echo "ERROR: invalid SEOS_TEST_DIR"
    exit 1
fi

DOCKER_IMAGE=jenkins/jenkinsfile-runner

DOCKER_RUN_PARAMS=(
    #-i
    #-t
    --rm
    #--hostname jenkinsfile-runner
    #-u $(id -u):$(id -g)
    -v /etc/localtime:/etc/localtime:ro
    -v ${SEOS_TEST_DIR}:/workspace
    -w /workspace
    --entrypoint bash
)

JENKINS_RUNNER_PARAMS=(
    /app/bin/jenkinsfile-runner
    -w /app/jenkins
    -p /usr/share/jenkins/ref/plugins
    -f /workspace/jenkinsfile/jenkions-cli/Jenkinsfile
)

DOCKER_PARAMS=(
    run
    ${DOCKER_RUN_PARAMS[@]}
    ${DOCKER_IMAGE}
    ${JENKINS_RUNNER_PARAMS[@]}
)

docker ${DOCKER_PARAMS[@]}
