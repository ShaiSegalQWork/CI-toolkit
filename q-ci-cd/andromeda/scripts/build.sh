#!/bin/bash

# expected script env var input:
#   GIT_HASH - git hash that should be checked out by single deployment

# quit if error in any command
set -e
# print each command
set -x

echo "SCRIPT INPUT PARAMS: \
    GIT_HASH=${GIT_HASH}"

sudo docker ps

ARTIFACTS_BASE_FOLDER="/mnt/Bits/Build_artifacts"

# generate datetime string
DATETIME=$(date +"%Y%m%d-%H%M%S")
# replace git special characters if branch if exist
BUILD_FOLDER="${DATETIME}_$(echo "$GIT_HASH" | sed 's/[^[:alnum:]]/-/g')"
echo "Build folder: ${BUILD_FOLDER}"

# create artifacts folder
ARTIFACTS_FOLDER="${ARTIFACTS_BASE_FOLDER}/andromeda/${BUILD_NUMBER}"
mkdir -p "${ARTIFACTS_FOLDER}"

# clean build folder
sudo rm -rf /tmp/andromeda_build

WORKING_BASE_FOLDER="/tmp/andromeda_build"

# create working directory and cd into it
WORKING_FOLDER="${WORKING_BASE_FOLDER}/${BUILD_FOLDER}"
mkdir -p "${WORKING_FOLDER}"
cd "${WORKING_FOLDER}"

# create folder for output artifacts
BUILD_RESULTS_FOLDER="${WORKING_FOLDER}/build_artifacts"
mkdir "${BUILD_RESULTS_FOLDER}"

# clone all required folders
git clone git@github.com:Q-cue-ai/system.git system
git clone git@github.com:Q-cue-ai/Silent-Speech.git Silent-Speech
git clone git@github.com:Q-cue-ai/Q-Commons.git Q-Commons

cd system
git pull 
git checkout "${GIT_HASH}"

cd ..
ls -al

sudo chown -R root:root "${WORKING_FOLDER}"

# pull required dockers
docker --version
sudo docker pull harbor.q.ai/cross-compilation/l4t-35.1.0-recorder:latest
sudo docker pull harbor.q.ai/cross-compilation/ubuntu-focal-recorder:latest

sudo docker images

CAMERA_PROCESSOR_FOLDER="system/q_cue_andromeda/q_services/camera_processor"
# run from within docker to build an app for the recorder station
sudo docker run --rm -v $(pwd):/ws --workdir /ws --platform linux/amd64 harbor.q.ai/cross-compilation/ubuntu-focal-recorder:latest /bin/bash -c 'ls -la && ./system/version_release.sh'
sudo find "${WORKING_FOLDER}/system" -regex '.*py_bindings\.cpython.*\.so' -exec mv '{}' "${BUILD_RESULTS_FOLDER}" \;
sudo rm "${WORKING_FOLDER}/${CAMERA_PROCESSOR_FOLDER}/build/camera_processor_service"
sudo find "${WORKING_FOLDER}/${CAMERA_PROCESSOR_FOLDER}/build" -maxdepth 1 -regex '.*camera_processor_service.*' -exec mv '{}' "${BUILD_RESULTS_FOLDER}/camera_processor_service_x86_64" \;

# remove cpp build folder so we can reuse same repo but with different docker
sudo rm -rf "${WORKING_FOLDER}/${CAMERA_PROCESSOR_FOLDER}/build"
# remove venv so it can be reinstalled in the next docker
sudo rm -rf "${WORKING_FOLDER}/system/venv"

# run from within docker to build an app for the jetson
sudo docker run --rm -v $(pwd):/ws --workdir /ws --platform linux/arm64 harbor.q.ai/cross-compilation/l4t-35.1.0-recorder:latest /bin/bash -c 'ls -la && ./system/version_release.sh'
sudo find "${WORKING_FOLDER}/system" -regex '.*py_bindings\.cpython.*\.so' -exec mv '{}' "${BUILD_RESULTS_FOLDER}" \;
sudo rm "${WORKING_FOLDER}/${CAMERA_PROCESSOR_FOLDER}/build/camera_processor_service"
sudo find "${WORKING_FOLDER}/${CAMERA_PROCESSOR_FOLDER}/build" -maxdepth 1 -regex '.*camera_processor_service.*' -exec mv '{}' "${BUILD_RESULTS_FOLDER}/camera_processor_service_aarch64" \;

# remove other aquitted container
sudo docker container rm `sudo docker ps -aq`

# own it
sudo chown -R jenkins:services "${BUILD_RESULTS_FOLDER}"
sudo chmod -R 755 "${BUILD_RESULTS_FOLDER}"

sudo chown -R jenkins:services "${ARTIFACTS_FOLDER}"
sudo chmod -R 755 "${ARTIFACTS_FOLDER}"

tar --verbose -czf "${ARTIFACTS_FOLDER}/package.tar.gz" -C "${BUILD_RESULTS_FOLDER}" .

echo "SUCCESS"