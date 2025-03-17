#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

#[help]Setup Foo/Bar version.
#[help]Usage: `--version=1`.

export CUSTOM_VERSION=$1
