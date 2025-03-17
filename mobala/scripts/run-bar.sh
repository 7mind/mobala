#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

function run-bar() {
    if [[ "${DO_BAR}" == 1 ]]; then
        echo "Bar: ${CUSTOM_VERSION}"
    fi
}
