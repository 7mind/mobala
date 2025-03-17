#!/usr/bin/env bash

set -euo pipefail

export CACHE_DIR="${XDG_CACHE_HOME:-"${HOME}/.cache"}"
export MOBALA_CACHE="${CACHE_DIR}/mobala.sh"
export MOBALA_CACHE_TMP="${CACHE_DIR}/mobala.sh.tmp"
export MOBALA_FILE="https://raw.githubusercontent.com/7mind/mobala/refs/heads/develop/mobala.sh"

if [[ -f "${MOBALA_CACHE_TMP}" ]]; then
    rm "${MOBALA_CACHE_TMP}"
fi

if [[ -f "${MOBALA_CACHE}" ]]; then
    is_cached=1
    echo "[info] Mobala.sh cache found at '${MOBALA_CACHE}'"
else
    echo "[info] Mobala.sh cache not found at '${MOBALA_CACHE}'"
    is_cached=0
fi

download_response=$(curl -sLJ0 -o "${MOBALA_CACHE_TMP}" -w "%{response_code}" "${MOBALA_FILE}" || true)
if [[ "${download_response}" == "200" ]]; then
    rm -rf "${MOBALA_CACHE}"
    mv "${MOBALA_CACHE_TMP}" "${MOBALA_CACHE}"
    echo "[info] Mobala.sh cache updated."
    is_cached=1
else
    echo "[warn] Mobala.sh download failed with ${download_response} status code."
    rm "${MOBALA_CACHE_TMP}"
fi

if [[ "${is_cached}" == 0 ]]; then
     >&2 echo "[error] Mobala.sh cache not found."
    exit 1
fi

export MOBALA_KEEP=${MOBALA_KEEP:-"$(pwd)/.keep.env"}
export MOBALA_ENV=${MOBALA_ENV:-"$(pwd)/devops/env.sh"}
export MOBALA_MODS=${MOBALA_MODS:-"$(pwd)/devops/mods"}
export MOBALA_PARAMS=${MOBALA_PARAMS:-"$(pwd)/devops/params"}

bash "${MOBALA_CACHE}" "$@"