#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

echo "[info] Setting up environment..."

# Default env
export NIXIFIED="${NIXIFIED:-0}"

# CI env
export BUILD_NUMBER="${BUILD_NUMBER:-0}"
export BUILD_BRANCH="${BUILD_BRANCH:-"$(git branch --show-current)"}"
declare -a BRANCH_PARTS="(${BUILD_BRANCH//\// })"
export SHORT_BRANCH=${BRANCH_PARTS[${#BRANCH_PARTS[@]}-1]}

# Mobala script
export DO_HELLO_WORLD="${DO_HELLO_WORLD:-0}"
export DO_HELLO_WORLD_NAME="${DO_HELLO_WORLD_NAME:-""}"
export DO_FOO="${DO_FOO:-0}"
export DO_BAR="${DO_BAR:-0}"

#[help]- Set `CUSTOM_VERSION` parameters to bypass --version params.
export CUSTOM_VERSION="${CUSTOM_VERSION:-"1"}"

# Source main script
source ./mobala/scripts/run.sh

if [[ "${DO_VERBOSE}" == 1 ]] ; then
  environment=$(env)
  environment=$(echo "$environment" | grep -v '^\s*$' | sed "s/^/[verbose:env] /;s/$/ /")
  echo "[verbose] Environment set:"
  echo "$environment"
fi
