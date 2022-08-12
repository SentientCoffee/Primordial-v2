#!/bin/sh

EXE_NAME="primordial"
BUILD_LABEL="release"
BUILD_LEVEL="speed"

DEBUG_FLAG=""
VET_FLAG=""

if [ "${1}" = "debug" ] ; then
    EXE_NAME="${EXE_NAME}_d"
    BUILD_LABEL="debug"
    BUILD_LEVEL="minimal"
    DEBUG_FLAG="-debug"
fi

[ "${1}" = "vet" ] && VET_FLAG="-vet"
[ "${2}" = "vet" ] && VET_FLAG="-vet"

BUILD_DIR="build/${BUILD_LABEL}"

[ -d "${BUILD_DIR}" ] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

echo -n "Building ${BUILD_LABEL} binary"
[ -n "${VET_FLAG}" ] && echo -n " (vetted)"
echo -e "...\n=========="

odin build primordial -out:${BUILD_DIR}/${EXE_NAME} -o:${BUILD_LEVEL} ${DEBUG_FLAG} ${VET_FLAG} -microarch:native -show-timings ||
   (echo -e "==========\nFailed!" && exit 1)

echo -e "==========\nDone."
