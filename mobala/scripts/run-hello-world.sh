#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

function run-hello-world() {
    if [[ "${DO_HELLO_WORLD}" == 1 ]]; then
        if [[ "${DO_HELLO_WORLD_NAME}" != "" ]]; then
            echo "Hello, ${DO_HELLO_WORLD_NAME}!"
        else
            echo "Hello, World!"
        fi
    fi
}