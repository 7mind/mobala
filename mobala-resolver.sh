#!/usr/bin/env bash

set -euo pipefail

export CACHE_DIR="${XDG_CACHE_HOME:-"${HOME}/.cache"}"
export MOBALA_CACHE="${CACHE_DIR}/mobala.sh"
export MOBALA_CACHE_TMP="${CACHE_DIR}/mobala.sh.tmp"
export MOBALA_FILE="https://raw.githubusercontent.com/7mind/mobala/refs/heads/release/mobala.sh"

function cleanup-cache() {
    rm -rf "${MOBALA_CACHE_TMP}"
    if [[ -f "${MOBALA_CACHE}" ]]; then
        echo "[info] Mobala.sh cache found at '${MOBALA_CACHE}'"
    else
        echo "[info] Mobala.sh cache not found at '${MOBALA_CACHE}'"
    fi
}

function update-cache() {
    download_response=$(curl -sLJ0 -o "${MOBALA_CACHE_TMP}" -w "%{response_code}" "${MOBALA_FILE}" || true)
    if [[ "${download_response}" == "200" ]]; then
        rm -rf "${MOBALA_CACHE}"
        mv "${MOBALA_CACHE_TMP}" "${MOBALA_CACHE}"
        echo "[info] Mobala.sh cache updated."
    else
        echo "[warn] Mobala.sh download failed with ${download_response} status code."
        rm "${MOBALA_CACHE_TMP}"
    fi
}

function verify-cache() {
    if ! [[ -f "${MOBALA_CACHE}" ]]; then
        >&2 echo "[error] Mobala.sh cache not found."
        exit 1
    fi
}

script_path="$(realpath "$0")"
script_dirname="$(dirname "$script_path")"
export MOBALA_PATH="${script_dirname}"
export MOBALA_KEEP=${MOBALA_KEEP:-"${MOBALA_PATH}/mobala/keep.env"}
export MOBALA_ENV=${MOBALA_ENV:-"${MOBALA_PATH}/mobala/env.sh"}
export MOBALA_MODS=${MOBALA_MODS:-"${MOBALA_PATH}/mobala/mods"}
export MOBALA_PARAMS=${MOBALA_PARAMS:-"${MOBALA_PATH}/mobala/params"}

cleanup-cache
update-cache
verify-cache

bash "${MOBALA_CACHE}" "$@"