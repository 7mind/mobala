#!/usr/bin/env bash

set -euo pipefail

function do-build() {
    step_run_cond run-bar
    step_run_cond run-foo
    step_run_cond run-hello-world
}
