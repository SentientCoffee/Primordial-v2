#!/bin/sh

MAIN_EXE_NAME="primordial"
SHADERCOMP_NAME="shadercomp"
BUILD_LABEL="release"
BUILD_LEVEL="speed"

DEBUG_FLAG=""
VET_FLAG=""

while getopts ":debug:vet:" opt ; do
    case "${opt}" in
        debug)
            EXE_NAME="${EXE_NAME}_d"
            BUILD_LABEL="debug"
            BUILD_LEVEL="minimal"
            DEBUG_FLAG="-debug"
        ;;

        vet)
            VET_FLAG="-vet"
        ;;

        *) ;;
    esac
done

BUILD_DIR="build/${BUILD_LABEL}"

[ -d "${BUILD_DIR}" ] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

printf -n "Building ${BUILD_LABEL} binaries"
[ -n "${VET_FLAG}" ] && printf " (vetted)"
printf "...\n==========\n"

echo "Shader compiler:"
odin run shadercomp -out:${BUILD_DIR}/${SHADERCOMP_NAME} -o:${BUILD_LEVEL} ${DEBUG_FLAG} ${VET_FLAG} -microarch:native -show-timings
[ "$?" -gt 0 ] && echo -e "==========\nBuild failed (shader compiler)!" && exit 1

echo "=========="
echo "Main program:"

odin build primordial -out:${BUILD_DIR}/${MAIN_EXE_NAME} -o:${BUILD_LEVEL} ${DEBUG_FLAG} ${VET_FLAG} -microarch:native -show-timings
[ "$?" -gt 0 ] && printf "==========\nBuild failed (Primordial)!" && exit 1
printf "==========\nBuild successful."
