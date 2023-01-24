#!/bin/sh

MAIN_EXE_NAME="primordial"
SHADERCOMP_NAME="shadercomp"
BUILD_LABEL="release"
BUILD_LEVEL="speed"

DEBUG_FLAG=""
VET_FLAG=""

bold_blue="\x1b[94;1m"
bold_red="\x1b[91;1m"
reset="\x1b[0m"

if [ "${1}" = "debug" ] ; then
    EXE_NAME="${EXE_NAME}_d"
    BUILD_LABEL="debug"
    BUILD_LEVEL="minimal"
    DEBUG_FLAG="-debug"
fi

[ "${1}" = "vet" ] && VET_FLAG="-vet"
[ "${2}" = "vet" ] && VET_FLAG="-vet"

ARGS=$(printf "%s\n" $@)

for arg in ${ARGS}; do
    case "${arg}" in
        debug)
            EXE_NAME="${EXE_NAME}_d"
            BUILD_LABEL="debug"
            BUILD_LEVEL="minimal"
            DEBUG_FLAG="-debug"
        ;;

        vet)
            VET_FLAG="-vet"
        ;;

        *)
            printf "${bold_red}Unknown option ${opt}!${reset}"
            exit 1
        ;;
    esac
done

BUILD_DIR="build/${BUILD_LABEL}"

[ -d "${BUILD_DIR}" ] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

printf "${bold_blue}Building ${BUILD_LABEL} binaries"
[ -n "${VET_FLAG}" ] && printf " (vetted)"
printf "...\n==========\n${reset}"

printf "${bold_blue}Shader compiler:\n${reset}"
odin run shadercomp -out:${BUILD_DIR}/${SHADERCOMP_NAME} -o:${BUILD_LEVEL} ${DEBUG_FLAG} ${VET_FLAG} -microarch:native -show-timings
[ "$?" -gt 0 ] && printf "${bold_red}==========\nBuild failed (shader compiler)!${reset}" && exit 1

printf "${bold_blue}==========\nMain program:\n${reset}"
odin build primordial -out:${BUILD_DIR}/${MAIN_EXE_NAME} -o:${BUILD_LEVEL} ${DEBUG_FLAG} ${VET_FLAG} -microarch:native -show-timings
[ "$?" -gt 0 ] && printf "${bold_red}==========\nBuild failed (Primordial)!${reset}" && exit 1
printf "${bold_blue}==========\nBuild successful.${reset}"
