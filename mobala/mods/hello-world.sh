#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

#[help]Print hello world:
#[help]--name=<name> to set user name (or `-n=<name>`).

export DO_HELLO_WORLD=1

for arg in "$@" ; do case $arg in
    -n=*|--name=*)
        export DO_HELLO_WORLD_NAME="${arg#*=}"
        ;;
    *)
        ;;
esac done
