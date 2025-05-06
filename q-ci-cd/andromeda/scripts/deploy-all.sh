#!/bin/bash

# expected script env var input:
#   DEPLOYED_HOST_NAMES - list of host names that require deploy
#   Q_BUILD_TO_DEPLOY - build number that produced the deployed artifacts
#   GIT_HASH - git hash that should be checked out by single deployment
#   SINGLE_DEPLOY_WAIT_ITERATIONS - how many seconds to wait for deployment to finish
#   SINGLE_DEPLOY_WAIT_SLEEP_SECS - how many seconds to wait for deployment to finish
#   REMOTE_USER_NAME - user name to use for ssh connection


### global env


set -x
set -e

echo "SCRIPT INPUT PARAMS: \
    DEPLOYED_HOST_NAMES=${DEPLOYED_HOST_NAMES}, \
    Q_BUILD_TO_DEPLOY=${Q_BUILD_TO_DEPLOY}, \
    GIT_HASH=${GIT_HASH}, \
    SINGLE_DEPLOY_WAIT_ITERATIONS=${SINGLE_DEPLOY_WAIT_ITERATIONS} \
    SINGLE_DEPLOY_WAIT_SLEEP_SECS=${SINGLE_DEPLOY_WAIT_SLEEP_SECS} \
    REMOTE_USER_NAME=${REMOTE_USER_NAME}"

BUILD_ARTIFACTS_PACKAGE_FULL_PATH="/mnt/Bits/Build_artifacts/andromeda/${Q_BUILD_TO_DEPLOY}/package.tar.gz"
if [ ! -f "${BUILD_ARTIFACTS_PACKAGE_FULL_PATH}" ]; then
    echo "Build artifacts for #${BUILD_ARTIFACTS_PACKAGE_FULL_PATH} don't exist"
    exit 1
fi


WORKING_DIR_BASE="$(pwd)/ANDROMEDA_DEPLOYS"
# remove previous deploys
rm -rf ${WORKING_DIR_BASE}
# generate datetime string
DATETIME=$(date +"%Y%m%d-%H%M%S")
# replace git special characters if branch if exist
WORKING_DIR="${DATETIME}_$(echo "$GIT_HASH" | sed 's/[^[:alnum:]]/-/g')"
WORKING_DIR_FULL_PATH="${WORKING_DIR_BASE}/${WORKING_DIR}"
echo "Working dir: ${WORKING_DIR_FULL_PATH}"

mkdir -p "${WORKING_DIR_FULL_PATH}"
pushd "${WORKING_DIR_FULL_PATH}"

CI_CD_PACKAGE_NAME="q_ci_cd"
git clone git@github.com:Q-cue-ai/q_ci_cd.git ${CI_CD_PACKAGE_NAME}
pushd ${CI_CD_PACKAGE_NAME}
git pull
git checkout master
pushd "./andromeda/py_code"
python3.10 -m venv venv
source ./venv/bin/activate
pip install -r requirements.txt
popd 
popd


### auxiliary functions


strip_string() {
    local INPUT_STRING="$1"
    local STRIPPED=$(echo "${INPUT_STRING}" | sed -e "s/^[[:space:]]*//" -e "s/[[:space:]]*$//")
    echo "${STRIPPED}"
}

prepare_configs() {
    local HOST_NAME="$1"
    local CONFIGS_FOLDER_FULL_PATH="$2"

    echo "Prepare configs for #${HOST_NAME} from ${CONFIGS_FOLDER_FULL_PATH}"

    HOST_CONFIGS_FULL_PATH="${CONFIGS_FOLDER_FULL_PATH}/${HOST_NAME}"
    if [ ! -d "${HOST_CONFIGS_FULL_PATH}" ]; then
        echo "Directory does not exist: ${HOST_CONFIGS_FULL_PATH}"
        exit 1
    fi

    BASE_CONFIGS_FULL_PATH="${CONFIGS_FOLDER_FULL_PATH}/base"
    PATCHED_HOST_CONFIGS_FULL_PATH="${CONFIGS_FOLDER_FULL_PATH}/${HOST_NAME}-patched"

    cp -r "${BASE_CONFIGS_FULL_PATH}" "${PATCHED_HOST_CONFIGS_FULL_PATH}"

    for CONFIG_PATCH_FULL_PATH in "${HOST_CONFIGS_FULL_PATH}"/*; do
      echo "Working on patch ${CONFIG_PATCH_FULL_PATH}"
      if [ ! -f "${CONFIG_PATCH_FULL_PATH}" ]; then
          echo "Skipping non-file item: ${CONFIG_PATCH_FULL_PATH}"
          continue
      fi

      PATCH_FILE_NAME=$(basename "${CONFIG_PATCH_FULL_PATH}")
      python ./merge_configs.py \
        --base "${BASE_CONFIGS_FULL_PATH}/${PATCH_FILE_NAME}" \
        --patch "${CONFIG_PATCH_FULL_PATH}" \
        --output "${PATCHED_HOST_CONFIGS_FULL_PATH}/${PATCH_FILE_NAME}"
    done
}



#### deploy in loop


# INPUT_FEATURE_RUN_PARAMS=$(split_by_comma $FEATURE_RUN_PARAMS)
NUM_HOST_NAMES=0
# -r	do not allow backslashes to escape any characters
# -a array	assign the words read to sequential indices of the array
IFS="," read -ra RECORDERS <<< "$DEPLOYED_HOST_NAMES"
for RECORDER in "${RECORDERS[@]}"; do
    echo "Recorder for the deployment: $RECORDER"
    let NUM_HOST_NAMES=$NUM_HOST_NAMES+1
done

echo "Num hosts found #${NUM_HOST_NAMES}"

DEPLOY_SINGLE_SCRIPT_NAME="deploy-single.sh"
CONFIGS_FOLDER_FULL_PATH="$(pwd)/q_ci_cd/andromeda/configs"
SINGLE_DEPLOY_SCRIPT_FULL_PATH="$(pwd)/q_ci_cd/andromeda/scripts/${DEPLOY_SINGLE_SCRIPT_NAME}"

pushd "./q_ci_cd/andromeda/py_code"

REMOTE_DEPLOYS_DIR_FULL_PATH="/home/recorder/Desktop/DEPLOYMENTS"

for RECORDER in "${RECORDERS[@]}"; do

    RECORDER=$(strip_string "${RECORDER}")
    echo "Working on recorder |${RECORDER}|"

    SPECIFIC_DEPLOY_DIR_FULL_PATH="${REMOTE_DEPLOYS_DIR_FULL_PATH}/${WORKING_DIR}"
    REMOTE_HOST_NAME="${REMOTE_USER_NAME}@${RECORDER}.q.ai"

    # create configs folder
    prepare_configs "${RECORDER}" "${CONFIGS_FOLDER_FULL_PATH}"
    PATCHED_CONFIG_FULL_PATH="${CONFIGS_FOLDER_FULL_PATH}/${RECORDER}-patched"

    ssh "${REMOTE_HOST_NAME}" "mkdir -p ${SPECIFIC_DEPLOY_DIR_FULL_PATH}"

    # copy deploy-single.sh
    scp "${SINGLE_DEPLOY_SCRIPT_FULL_PATH}" "${REMOTE_HOST_NAME}:${SPECIFIC_DEPLOY_DIR_FULL_PATH}/"
    # make deploy-single.sh executable
    ssh "${REMOTE_HOST_NAME}" "chmod +x ${SPECIFIC_DEPLOY_DIR_FULL_PATH}/${DEPLOY_SINGLE_SCRIPT_NAME}"
    # copy built artifacts
    scp "${BUILD_ARTIFACTS_PACKAGE_FULL_PATH}" "${REMOTE_HOST_NAME}:${SPECIFIC_DEPLOY_DIR_FULL_PATH}/"
    # copy config folder
    scp -r "${PATCHED_CONFIG_FULL_PATH}" "${REMOTE_HOST_NAME}:${SPECIFIC_DEPLOY_DIR_FULL_PATH}/config"

    # executed deploy-single.sh script
    ssh "${REMOTE_HOST_NAME}" "pushd ${SPECIFIC_DEPLOY_DIR_FULL_PATH} && GIT_HASH=${GIT_HASH} ./${DEPLOY_SINGLE_SCRIPT_NAME}" &

done


### monitor


# go back to working folder
popd
SUCCESSES_DIR_FULL_PATH="$(pwd)/SUCCESSES"
mkdir -p "${SUCCESSES_DIR_FULL_PATH}"


ITERATION=1
while [ ${ITERATION} -le ${SINGLE_DEPLOY_WAIT_ITERATIONS} ]
do
    echo "Performing wait iteration ${ITERATION}"

    for RECORDER in "${RECORDERS[@]}"; do
    	echo "Checking recorder $RECORDER"
        SPECIFIC_DEPLOY_DIR_FULL_PATH="${REMOTE_DEPLOYS_DIR_FULL_PATH}/${WORKING_DIR}"
        REMOTE_SUCCESS_EXISTS=$(ssh ${REMOTE_USER_NAME}@${RECORDER}.q.ai "test -e ${SPECIFIC_DEPLOY_DIR_FULL_PATH}/SUCCESS && echo 'true' || echo 'false'")
        if [ "${REMOTE_SUCCESS_EXISTS}" = "true" ]; then
            echo "SUCCESS file exists on ${RECORDER}"
            touch ${SUCCESSES_DIR_FULL_PATH}/${RECORDER}
        fi
    done

    NUM_SUCCESSES=$(find "${SUCCESSES_DIR_FULL_PATH}" -maxdepth 1 -type f \( -not -path "*.DS_Store*" \) | wc -l)
    if [ ${NUM_SUCCESSES} -eq ${NUM_HOST_NAMES} ]; then
        echo "All deployments finished"
        break
    fi

    sleep ${SLEEP_DURATION_SECS}
    
    let ITERATION=$ITERATION+1
done

if [ ${ITERATION} -eq ${SINGLE_DEPLOY_WAIT_ITERATIONS} ]; then
    echo "Failed to deploy. Machines that succeeded:"
    ls -la ${SUCCESSES_DIR_FULL_PATH}
    exit 1
fi

echo "SUCCESS"
