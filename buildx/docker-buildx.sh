#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

# Save working directory
OLD_PWD="$PWD"
# Return to saved working directory on error/exit
trap_handler() {
  cd "$OLD_PWD" || exit 9
}
trap "trap_handler" ERR EXIT INT TERM

cd "$(dirname "${BASH_SOURCE[0]}")" || return

# Command line argument parsing based on example from https://stackoverflow.com/a/29754866
# Credits @ Robert Siemer

! getopt --test >/dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  echo "I’m sorry, \"getopt --test\" failed in this environment."
  exit 1
fi

OPTIONS=t:b:f:s
LONGOPTS=base-image:,docker-build-tag:,file:,targets:,skip-build,build-container,fast

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  echo "Paramter parsing failed"
  exit 2
fi

eval set -- "$PARSED"

DOCKER_BUILD_TAG_ARG="develop"
BASE_IMAGE_ARG="gcr.io/distroless/java17-debian11"
TARGETS="core"
FILES=""
BUILD_CONTAINER=0
SKIP_BUILD=0
FAST_BUILD=0

while true; do
  case "$1" in
  -f | --file)
    FILES="${FILES}-f $2 "
    shift 2
    ;;
  --targets)
    TARGETS="$2"
    shift 2
    ;;
  -b | --base-image)
    BASE_IMAGE_ARG="$2"
    shift 2
    ;;
  -t | --docker-build-tag)
    DOCKER_BUILD_TAG_ARG="$2"
    shift 2
    ;;
  --build-container)
    BUILD_CONTAINER=1
    shift 1
    ;;
  -s | --skip-build)
    SKIP_BUILD=1
    shift 1
    ;;
  --fast)
    FAST_BUILD=1
    shift 1
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Unknown parameter $1"
    exit 3
    ;;
  esac
done

# Enable experimental Docker features (buildx)
export DOCKER_CLI_EXPERIMENTAL="enabled"

# Export vars for buildx bake yaml resolution
export DOCKER_BUILD_TAG="$DOCKER_BUILD_TAG_ARG"
export BASE_IMAGE="$BASE_IMAGE_ARG"
printf "######################################################################\n"
printf "Using build tag \"%s\" and base image \"%s\"\n" "$DOCKER_BUILD_TAG" "$BASE_IMAGE"
printf "######################################################################\n\n"

if [ $BUILD_CONTAINER = 1 ]; then
  echo "Building build-container via \"docker buildx bake build-container ${FILES}$*\"..."
  eval "docker buildx bake build-container ${FILES}$*"
  exit
fi
if [ $SKIP_BUILD = 0 ]; then
  if [ $FAST_BUILD = 1 ]; then
    echo "Executing fast local build with fastBuild.sh..."
    echo ""
    ../fastBuild.sh
  else
    echo "Executing Docker build with build.sh..."
    echo ""
    ../build.sh
  fi
# Check whether preconditions are fulfilled
elif [[ ! -d "../ids-connector/build/libs/projectJars" ]]; then
  printf "\e[31m################################################################################\n"
  printf "Directory ../ids-connector/build/libs/projectJars not found, this build might fail.\n"
  printf "Please build trusted connector first via \"build.sh\".\n"
  printf "If build.sh cannot pull build-container, run this command first:\n%s --build-container\n" "$0"
  printf "################################################################################\e[0m\n\n"
fi

# shellcheck disable=SC2155
PROJECT_VERSION=$(cat ../version.txt)
# Export var for buildx bake yaml resolution
export PROJECT_VERSION
printf "######################################################################\n"
printf "Detected project version: %s\n" "$PROJECT_VERSION"
printf "######################################################################\n\n"

echo "Building images via \"docker buildx bake $TARGETS ${FILES}$*\"..."
eval "docker buildx bake $TARGETS ${FILES}$*"
