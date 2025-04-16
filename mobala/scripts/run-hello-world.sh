#!/usr/bin/env bash

set -euo pipefail

function run-hello-world() {
    if [[ "${DO_HELLO_WORLD_NAME}" != "" ]]; then
        echo "Hello, ${DO_HELLO_WORLD_NAME}!"
    else
        echo "Hello, World!"
    fi
}
