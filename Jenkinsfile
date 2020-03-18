
// bind the localtime to docker container to avoid problems of gaps between the
// localtime of the container and the host.
// add to group "stack" in order to grant usage of Haskell stack in the docker
// image

def DOCKER_BUILD_ENV = [ image: 'seos_build_env_20191010',
                         args: ' -v /etc/localtime:/etc/localtime:ro '+
                               ' --group-add=1001'
                       ]

def DOCKER_TEST_ENV = [
    image:      'docker:5000/seos_test_env:latest',
    args:       ' -v /home/jenkins/.ssh/:/home/jenkins/.ssh:ro'+
                    ' -v /etc/localtime:/etc/localtime:ro' +
                    ' --network=host' +
                    ' --cap-add=NET_ADMIN' +
                    ' --cap-add=NET_RAW' +
                    ' --device=/dev/net/tun',
    registry:   'http://docker:5000'
]


def print_step_info(name) { echo "#################### " + name }

pipeline {
    agent {
        // run everything in the build machines, as we don't run any test
        // besides the unit tests so far.
        label "build"
    }
    options {
        skipDefaultCheckout()
        // disableConcurrentBuilds()
    }
    stages {
        stage('clean_checkout') {
            steps {
                print_step_info env.STAGE_NAME
                cleanWs()
                dir('scm-src') { checkout scm }
            }
        }
        stage('build') {
            agent {
                docker {
                    reuseNode true
                    image DOCKER_BUILD_ENV.image
                    args DOCKER_BUILD_ENV.args
                }
            }
            steps {
                print_step_info env.STAGE_NAME
                sh 'scm-src/build-sdk.sh all sdk-package'
            }
        }
        stage('astyle_check') {
            agent {
                docker {
                    reuseNode true
                    image DOCKER_BUILD_ENV.image
                    args DOCKER_BUILD_ENV.args
                }
            }
            steps {
                print_step_info env.STAGE_NAME
                catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                    sh '''#!/bin/bash -ue
                          find . -name 'astyle_check.sh' -printf 'running %p\n' -execdir {} \\;
                          files=$(find . -name '*.astyle')
                          if [ ! -z "${files}" ]; then
                              echo "ERROR: source is not astyle compliant, check: "
                              for file in ${files}; do
                                  echo "  ${file}"
                              done
                              exit 1
                          fi'''
                }
            }
        }
        stage('test') {
            agent {
                docker {
                    reuseNode true
                    alwaysPull true
                    registryUrl DOCKER_TEST_ENV.registry
                    image DOCKER_TEST_ENV.image
                    args DOCKER_TEST_ENV.args
                }
            }
            steps {
                print_step_info env.STAGE_NAME
                catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') {
                    sh 'scm-src/build-sdk.sh unit-tests sdk-package'
                }
            }
        }
    }
    post {
        always {
            print_step_info 'archive artifacts'
            sh 'tar -cjf sdk-package.bz2 sdk-package/'
            archiveArtifacts artifacts: 'sdk-package.bz2', fingerprint: true
        }
    }
}
