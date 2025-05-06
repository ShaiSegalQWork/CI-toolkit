#!/bin/bash

# expected script env var input:
#   GIT_HASH - git hash that should be checked out by single deployment


### aux functions


log() {
    DATETIME=$(date +"%Y-%m-%d_%H:%M:%S")
    echo "${DATETIME} | ${1}" >> "$(pwd)/deploy-single.log"
}

echo_and_log() {
    echo "${1}"
    log "${1}"
}


### set up env


ANDROMEDA_MAIN_PACKAGE="system"
BUILD_ARTIFACTS_DIR="build"
DEPLOYS_FOLDER_NAME="DEPLOYMENTS"

BRANCH_TO_CHECKOUT="${GIT_HASH}"
if [ -z "${BRANCH_TO_CHECKOUT}" ]; then
    BRANCH_TO_CHECKOUT="master"
fi
echo_and_log "Branch to checkout: ${BRANCH_TO_CHECKOUT}"

# should be x86_64 for desktop and aarch64 for jetson
CPU_ARCH=$(uname -m)
echo_and_log "CPU Architecture: $CPU_ARCH"

### single deployment


echo_and_log "Working on single deployment for $(hostname)"

# get the script's directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
echo_and_log "Script location: $SCRIPT_DIR"
pushd "${SCRIPT_DIR}"

# open built app tar.gz
mkdir "${BUILD_ARTIFACTS_DIR}"
tar -xf package.tar.gz -C "${BUILD_ARTIFACTS_DIR}"

echo_and_log "Clone repos"
git clone git@github.com:Q-cue-ai/system.git system
git clone git@github.com:Q-cue-ai/Silent-Speech.git Silent-Speech
git clone git@github.com:Q-cue-ai/Q-Commons.git Q-Commons

pushd "${ANDROMEDA_MAIN_PACKAGE}" || exit 1
git pull
git checkout "${BRANCH_TO_CHECKOUT}"

echo_and_log "Activate python env from $(which python)"
python3.10 -m venv venv
source ./venv/bin/activate

# reqs below should be installed first to avoid instllation problem with spdlog 
# for example: error: [Errno 2] No such file or directory: 'vext'
echo_and_log "Pip install setuptools, wheel, pybind11"
pip install setuptools==67.6.1
pip install wheel==0.40.0
pip install pybind11==2.10.3
pip install vext==0.7.6
pip install vext.gi==0.7.4

echo_and_log "Install app dependencies"
pip install -e ../Q-Commons
pip install -e ../Silent-Speech
pip install -r requirements.txt

echo_and_log "Install app itself"
pip install -e .

popd

echo_and_log "Copy compiled camera processor to the ${ANDROMEDA_MAIN_PACKAGE}"
CAM_PROCESSOR_FILE_NAME_PATH=$(find ${BUILD_ARTIFACTS_DIR} -type f -name "*camera_processor_service_${CPU_ARCH}*")
CAM_PROCESSOR_FILE_NAME=$(basename "$CAM_PROCESSOR_FILE_NAME_PATH")
CAM_PROCESSOR_FILE_FULL_PATH="$(pwd)/${BUILD_ARTIFACTS_DIR}/${CAM_PROCESSOR_FILE_NAME}"
echo_and_log "Camera processor file name: ${CAM_PROCESSOR_FILE_NAME}, at: ${CAM_PROCESSOR_FILE_FULL_PATH}"
ANDROMEDA_MAIN_PACKAGE_FULL_PATH=$(pwd)/${ANDROMEDA_MAIN_PACKAGE}
CAM_PROCESSOR_APP_REL_DIR_PATH="services/camera_processor/build"
CAM_PROCESSOR_APP_DIR="${ANDROMEDA_MAIN_PACKAGE_FULL_PATH}/${CAM_PROCESSOR_APP_REL_DIR_PATH}"
mkdir -p "${CAM_PROCESSOR_APP_DIR}"
cp "${CAM_PROCESSOR_FILE_FULL_PATH}" "${CAM_PROCESSOR_APP_DIR}"
CAM_PROCESSOR_FILE_COPIED_PATH="${CAM_PROCESSOR_APP_DIR}/${CAM_PROCESSOR_FILE_NAME}"
echo_and_log "Copied camera processor to ${CAM_PROCESSOR_FILE_COPIED_PATH}"
EXPECTED_CAM_PROCESSOR_FILE_NAME="camera_processor_service"
echo_and_log "Create soft link from ${CAM_PROCESSOR_FILE_COPIED_PATH} to ${CAM_PROCESSOR_APP_DIR}/${EXPECTED_CAM_PROCESSOR_FILE_NAME}"
ln -s ${CAM_PROCESSOR_FILE_COPIED_PATH} "${CAM_PROCESSOR_APP_DIR}/${EXPECTED_CAM_PROCESSOR_FILE_NAME}"

echo_and_log "Copy pybindings to the ${ANDROMEDA_MAIN_PACKAGE_FULL_PATH}"
PYBINDINGS_FILE_NAME_PATH=$(find ${BUILD_ARTIFACTS_DIR} -type f -name "*py_bindings.cpython-310-${CPU_ARCH}*")
PYBINDINGS_FILE_NAME=$(basename "$PYBINDINGS_FILE_NAME_PATH")
PYBINDINGS_FILE_FULL_PATH="$(pwd)/${BUILD_ARTIFACTS_DIR}/${PYBINDINGS_FILE_NAME}"
echo_and_log "Pybindings file name: ${PYBINDINGS_FILE_NAME}, at: ${PYBINDINGS_FILE_FULL_PATH}"
cp "${PYBINDINGS_FILE_FULL_PATH}" "${ANDROMEDA_MAIN_PACKAGE_FULL_PATH}"

APP_CONFIG_REL_DIR_PATH="q_cue_andromeda/q_services/q_system/config"
DESTINATION_CONFIG_FULL_PATH="${ANDROMEDA_MAIN_PACKAGE_FULL_PATH}/${APP_CONFIG_REL_DIR_PATH}"
CONFIGS_FULL_PATH="$(pwd)/config"
echo_and_log "Copy config file to ${DESTINATION_CONFIG_FULL_PATH} from ${CONFIGS_FULL_PATH}"
cp -rf "${CONFIGS_FULL_PATH}" "${DESTINATION_CONFIG_FULL_PATH}"

CURRENT_DEPLOY_LINK="$(dirname ${SCRIPT_DIR})/current"
echo_and_log "Remove soft link: ${CURRENT_DEPLOY_LINK}"
rm -f "${CURRENT_DEPLOY_LINK}"
echo_and_log "Link ${ANDROMEDA_MAIN_PACKAGE_FULL_PATH} TO ${CURRENT_DEPLOY_LINK}"
ln -sf "${ANDROMEDA_MAIN_PACKAGE_FULL_PATH}" "${CURRENT_DEPLOY_LINK}"

touch "$(pwd)/SUCCESS"
echo_and_log "SUCCESS TO SINGLE DEPLOY"
