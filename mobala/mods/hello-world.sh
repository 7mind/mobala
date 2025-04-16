#!/usr/bin/env bash

set -euo pipefail

#[help]Print hello world:
#[help]--name=<name> to set user name (or `-n=<name>`).

step_enable run-hello-world

for arg in "$@" ; do case $arg in
    -n=*|--name=*)
        export DO_HELLO_WORLD_NAME="${arg#*=}"
        ;;
    *)
        ;;
esac done
