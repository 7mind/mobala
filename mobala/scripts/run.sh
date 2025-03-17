#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

source ./mobala/scripts/run-hello-world.sh
source ./mobala/scripts/run-foo.sh
source ./mobala/scripts/run-bar.sh

function run() {
    run-hello-world
    run-foo
    run-bar
}
