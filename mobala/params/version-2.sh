#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

#[help]Setup Foo/Bar version to 2.
#[help]Usage: `--version-2`.

export CUSTOM_VERSION="2"
