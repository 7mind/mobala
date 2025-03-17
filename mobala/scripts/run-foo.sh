#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

function run-foo() {
    if [[ "${DO_FOO}" == 1 ]]; then
        echo "Foo: ${CUSTOM_VERSION}"
    fi
}
