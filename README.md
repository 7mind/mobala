# Modular Bash Launcher

Module based Bash script launcher or Mobala!

## Using resolver:

Copy [mobala-resolver.sh](./mobala-resolver.sh) content to the file in the root of your project (eg `./run`).
Execute with `./run --verbose --nix --param :my-mode`.

That's it! You are ready to write your modular Bash script!

## Mobala project structure:

Mobala project have four environment variables, specifying at where to lookup execution scripts:

* `MOBALA_KEEP` - file with the list of all environment variables that should be preserved in Nix environment (default
  `$(pwd)/mobala/keep.env`);
* `MOBALA_ENV` - bash script to setup execution environment (default `$(pwd)/mobala/env.sh`);
* `MOBALA_MODS` - directory of shell scripts to modify environment (default `$(pwd)/mobala/mods`);
* `MOBALA_PARAMS` - directory of shell scripts to pass parameters to environment (default `$(pwd)/mobala/params`).

`MOBALA_ENV` environment setup shell script will be sourced after execution environment is prepared.
Mobala executor expects `run` function to be sourced and ready to be executed after `MOBALA_ENV` sourcing.
`run` function is a main entrypoint of all project.

## Mobala builtin commands:

* `--help` to print auto-generated help;
* `--nix` to shift script execution to `nix develop` shell, using local `flake.nix` definition;
* `--verbose` or `-v` to enable verbose logging;
* `--env PARAM=123` or `-e PARAM=123` to specify environment variable (should be specified AFTER `--nix` option, or
  environment might be lost during execution)

## Writing your script:

There is two ways of adding a script:

1. Add script file to `${MOBALA_MODS}/my-script.sh`, run it with `./run :my-script`
2. Add mode file to `${MOBALA_MODS}/my-script.sh` to set up script execution:

```shell
#!/usr/bin/env bash

set -euo pipefail
if [[ "${DO_VERBOSE}" == 1 ]] ; then set -x ; fi

#[help]Print foo, using provided parameters.

export DO_MY_SCRIPT=1
```

Update `run` command in `MOBALA_ENV` to execute your script if `"${DO_MY_SCRIPT}" == 1`.

Example:

* Mode environment setup - [hello-world.sh](./mobala/mods/hello-world.sh);
* Mode script - [run-hello-world.sh](./mobala/scripts/run/hello-world.sh);
* Runner - [run.sh](./mobala/scripts/run.sh).

## Adding parameters to your script

Mobala launcher will automatically parse and pass all CLI arguments from original CLI string to mode script.
Arguments parsing should be handled by the mode itself.

Example: [hello-world.sh](./mobala/mods/hello-world.sh) - run with
`./mobala-resolver.sh :hello-world --name="John Doe"`.

## Running your script

Mobala launcher will parse CLI arguments, with the following syntax:

* `--param` - to specify global parameter (should be set before first mode)
* `:mode -p1 --mode-arg=foo --param` - to apply execution mode and specify its parameters.

Arguments and modes might be combined in any form:

```shell
./mobala-resolver.sh \
  --global-parameter \
  --global-parameter-2=foo \
  :mode-1 --mode-1-param --mode-1-arg=John \
  :mode-2 --mode-2-param --mode-2-arg=Doe
```

## Adding global parameters

Add parameter reader shell script to `MOBALA_PARAMS` as `${MOBALA_PARAMS}/my-parameter.sh`.
All parameters set as `--my-param=123` or `--my-param` before first mode invocation are used to invoke
`${MOBALA_PARAMS}/my-param.sh`

Examples:

* [version.sh](./mobala/params/version.sh): run with `./mobala-resolver.sh --version=123 :foo`;
* [version-1.sh](./mobala/params/version-1.sh): run with `./mobala-resolver.sh --version-1 :bar`;

## Help

Project help is auto generated. To specify help for env/modes/params helps leave a comment in your script,
starting from `#[help]`. Every line starting with `#[help]` will be parsed as a manual string and auto-added to the
Mobala component help.

Show help with `./mobala-resolver.sh --help`.

Examples:

* Parameter help at [version.sh](./mobala/params/version.sh);
* Mode help at [hello-world.sh](./mobala/mods/hello-world.sh);
* Env help at [env.sh](./mobala/env.sh);