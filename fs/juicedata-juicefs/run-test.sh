#!/bin/bash

set -o errexit
set -o xtrace

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

JUICEFS_DIR="${SCRIPT_DIR}/juicefs"
JFS_BIN=${JUICEFS_DIR}/juicefs
JFS_MOUNT=${JUICEFS_DIR}/jfs

mkdir ${JUICEFS_DIR}

curl -sSL https://juicefs.com/static/juicefs -o ${JFS_BIN} && chmod +x ${JFS_BIN}
${JFS_BIN} auth $JFS_NAME --token $JFS_TOKEN --accesskey $JFS_ACCESSKEY --secretkey $JFS_SECRETKEY
${JFS_BIN} mount $JFS_NAME $JFS_MOUNT

pushd $JFS_MOUNT
prove --recurse --failures ${SCRIPT_DIR}/../.. || true # ignore test result
uname -a
${JFS_BIN} version
popd
