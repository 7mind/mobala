#!/usr/bin/env bash

set -euo pipefail

source ./mobala/scripts/run-hello-world.sh
source ./mobala/scripts/run-foo.sh
source ./mobala/scripts/run-bar.sh

function steps_register() {
    step_register run-hello-world
    step_register run-foo
    step_register run-bar
}
