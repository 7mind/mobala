# Modular Bash Launcher

Modular Bash Launcher or Mobala! Comes with Nix Flake support.

This project is a simple way to create modular Bash scripts useful in various CI workflows.

It allows you to define a Bash functions (called "Flows") consisting of several "Steps" (which also are Bash functions).
Each Step can have its own arguments and parameters and can be explicitly enabled or disabled before Flow execution.

[mobala-resolver.sh](./mobala-resolver.sh) is the primary entrypoint which is responsible for maintaining an up-to-date local
copy of the main script.

## Setting things up

1. Copy [mobala-resolver.sh](./mobala-resolver.sh) into the root directory of your project with a name up to your liking, e.g. `./run`.
2. Create executable `.mobala/env.sh` file, define all the shared environment variables there, that file is sourced before Flows start being processed.
3. Create a flow in `.mobala/flows/` directory
3. Create a step in `.mobala/steps/` directory

Launch the entrypoint with `./run --verbose --nix --param :my-mode`.

Read below for more details.

## Defining Flows

Each Flow is defined in a separate file in `.mobala/flows` directory. The name of the file is the name of the Flow with prefix `do-`. For example, `do-build`. Each Flow file should have a Flow Definition, which is a function with the same name as the Flow file. Each Flow Definition should refer Steps using `step_run_cond` function, for example

```bash
#!/usr/bin/env bash

set -euo pipefail

function do-build() {
    step_run_cond run-compile
    step_run_cond run-test
}
```

It's up to user to process the script arguments and decide which Flows should be executed when the script launches, it's done in `.mobala/env.sh`

In order to mark Flow for execution, the user should call `flow_enable` function, for example:

```bash
flow_enable do-build
```

## Defining Steps

Each Step is defined in a separate file in `.mobala/steps` directory. The name of the file is the name of the Step with prefix `run-`. For example, `run-test`. Each Step file should have a Step Definition, which is a function with the same name as the Step file. Each Step Definition is just an arbitrary Bash function, for example:

```bash
#!/usr/bin/env bash

set -euo pipefail

function run-hello-world() {
    if [[ "${DO_HELLO_WORLD_NAME}" != "" ]]; then
        echo "Hello, ${DO_HELLO_WORLD_NAME}!"
    else
        echo "Hello, World!"
    fi
}
```

### Parsing Step Arguments

All the steps are disabled by default. In order to enable a step, we should define a commandline parser, which is a script in `.mobala/mods` directory. The name of the parser file might be arbitrary.

Mobala parses its command line and separate it by strings prefixed with `:`, everything what comes after it will be passed to the parser with matching name.

For example, if the user launches Mobala with parameters `:say-hello --name=John Doe :say-bye`, Mobala will run script named `.mobala/mods/say-hello.sh` passing `--name=John Doe` to it and then will run `.mobala/mods/say-bye.sh`. Everything what comes before first `:` argument is treated as a global argument and can be processed by `env.sh`.

The parser scripts may enable steps by calling `step_enable` and define various environment variables, for example:

```bash
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
```

All the commented lines starting with `#[help]` will be treated as documentation and visible in `--help` output.


## Mobala builtin commands:

* `--help` to print auto-generated help;
* `--nix` to shift script execution to `nix develop` shell, using local `flake.nix` definition;
* `--verbose` or `-v` to enable verbose logging;
* `--env PARAM=123` or `-e PARAM=123` to specify environment variable (should be specified AFTER `--nix` option, or
  environment will be lost after switching into Nix)

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
