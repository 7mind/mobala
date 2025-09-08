#!/usr/bin/env bash

set -euo pipefail




function print-command-help() {
    local command="$1"
    local command_help="$2"

    local help_indent=$(printf "%*s" "${#command}" "")
    local help_head=$(echo "${command_help}" | sed -n "1p")
    local help_tail=$(echo "${command_help}" | sed -n "1!p" | prefix_each_line " ${help_indent}")
    echo "$(echo-bold $command) ${help_head}"
    if [[ "${help_tail}" != "" ]]; then
      echo "${help_tail}"
    fi
    echo
}

function print-help() {
    echo-bold "Welcome to Modular Bash Launcher!"

    if [[ -f "${MOBALA_ENV}" ]]; then
        echo-bold "Mobala environment (${MOBALA_ENV}):"
        local env_help=$(cat "${MOBALA_ENV}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
        echo "${env_help}"
        echo
    fi

    echo-bold "Mobala parameters (${MOBALA_PARAMS}):"
    print-command-help "--nix" "Nixify runner commands."
    print-command-help "--verbose|-v" "Enable verbose logging for runner commands."
    print-command-help "--env|-e" 'Specify environment variable. Usage `-e PARAM=test`.'
    if [[ -d "${MOBALA_PARAMS}" ]]; then
        local params=($(ls -f $MOBALA_PARAMS | sort | grep ".sh" || true))
        for param in "${params[@]}"; do
            param_name="${param::-3}"
            param_help=$(cat "${MOBALA_PARAMS}/${param}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
            print-command-help "--${param_name}" "${param_help}"
        done
    fi

    if [[ -d "${MOBALA_MODS}" ]]; then
        echo-bold "Mobala modes (${MOBALA_MODS}):"
        local mods=($(ls -f $MOBALA_MODS | sort | grep ".sh" || true))
        for mode in "${mods[@]}"; do
            mode_name="${mode::-3}"
            mode_help=$(cat "${MOBALA_MODS}/${mode}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
            print-command-help ":${mode_name}" "${mode_help}"
        done
    fi
}

# nix: begin --------------------------------------------------------------------------------------
export NIXIFIED=${NIXIFIED:-0}

function nixify() {
    read -r -a args <<< "$(grep -v '^\s*$' $MOBALA_KEEP | grep -v '#' | sed "s/^/--keep /;s/$/ /" | tr '\n' ' ')"

    local func_args=("$@")
    local last_index=$(( ${#func_args[@]} - 1 ))
    local last_arg="${func_args[$last_index]}"
    local dev_shell=".#$last_arg"

    if [[ -z "${IN_NIX_SHELL+x}" ]]; then
        echo "[info] Restarting in Nix..."
        export NIXIFIED=1
        nix flake lock
        nix flake metadata
        exec nix develop \
          $dev_shell \
          --ignore-environment \
          --keep HOME \
          --keep NIXIFIED \
          --keep MOBALA_SUBDIR \
          --keep MOBALA_PATH \
          --keep MOBALA_KEEP \
          --keep MOBALA_ENV \
          --keep MOBALA_MODS \
          --keep MOBALA_PARAMS \
          --keep DO_VERBOSE \
          --keep CI \
          --keep CI_BRANCH \
          --keep CI_COMMIT \
          --keep CI_BRANCH_TAG \
          --keep CI_PULL_REQUEST \
          --keep CI_BUILD_UNIQ_SUFFIX \
          "${args[@]:-}" \
          --command bash "$script_path" "$@"
    fi
}
# nix: end ----------------------------------------------------------------------------------------

# logging: begin ----------------------------------------------------------------------------------
function echo-bold() {
    local bold=$(tput bold)
    local normal=$(tput sgr0)
    echo "${bold}$1${normal}"
}

function prefix_each_line() {
    local prefix="$1"
    while IFS= read -r line; do
        echo "${prefix}${line}"
    done
}

export DO_VERBOSE=${DO_VERBOSE:-0}

function invoke_quiet() {
  { local IS_VERBOSE=1 ; } > /dev/null 2>&1
  { [[ $- == *x* ]] && IS_VERBOSE=1 || IS_VERBOSE=0 ; } > /dev/null 2>&1
  { set +x ; } > /dev/null 2>&1
  local name=$1
  shift
  $name $*
  { [[ "${IS_VERBOSE}" == 1 ]] && set -x || set +x ; } > /dev/null 2>&1
}

function invoke_verbose() {
  local name=$1
  shift
  { [[ "${DO_VERBOSE}" == 1 ]] && set -x || set +x ; } > /dev/null 2>&1
  $name $*
  { set +x ; } > /dev/null 2>&1
}

function debug_env() {
    if [[ "${DO_VERBOSE}" == 1 && "${VERBOSE_LEVEL}" -gt 1 ]] ; then
    environment=$(env)
    environment=$(echo "$environment" | grep -v '^\s*$' | sed "s/^/[verbose:env] /;s/$/ /")
    echo "[verbose] Environment set:"
    echo "$environment"
    fi
}
# logging: end-- ----------------------------------------------------------------------------------

# modules: begin ----------------------------------------------------------------------------------
declare -a MOBALA_REG_COMMANDS
declare -a MOBALA_REG_FLOWS

function flows_register() {
  for flow in ${MOBALA_FLOWS}/do-*.sh; do
    local name=$(basename "${flow%.*}")
    source "${flow}"
    flow_register $name
  done
}

function steps_register() {
  for step in ${MOBALA_STEPS}/run-*.sh; do
    local name=$(basename "${step%.*}")
    source "${step}"
    step_register $name
  done
}

function step_register() {
  local varname="RUN__${1//-/_}"
  local enabled=${!varname:-0}
  MOBALA_REG_COMMANDS+=($1)
  #  eval "export $varname=$enabled"
  declare -gx "${varname}=${enabled}"
}

function flow_register() {
  echo "Will register $1"
  local varname="RUNFLOW__${1//-/_}"
  local enabled=${!varname:-0}
  MOBALA_REG_FLOWS+=($1)
  #  eval "export $varname=$enabled"
  declare -gx "${varname}=${enabled}"
}

function flow_enable() {
  local varname="RUNFLOW__${1//-/_}"
  #  eval "export $varname=1"
  declare -gx "${varname}=1"
}


function step_enable() {
  local varname="RUN__${1//-/_}"
  #  eval "export $varname=1"
  declare -gx "${varname}=1"
}

function steps_report() {
  echo "${MOBALA_REG_FLOWS[@]}"
  echo "The following flows will run:"
  for func in "${MOBALA_REG_FLOWS[@]}"; do
    local varname="RUNFLOW__${func//-/_}"
    if [[ "${!varname}" == 1 ]]; then
        echo "[*] ${func}"
    else
        echo "[ ] ${func}"
    fi
  done

  echo "The following steps may run:"
  for func in "${MOBALA_REG_COMMANDS[@]}"; do
    local varname="RUN__${func//-/_}"
    if [[ "${!varname}" == 1 ]]; then
        echo "[*] ${func}"
    else
        echo "[ ] ${func}"
    fi
  done
}

function flows_run() {
  for func in "${MOBALA_REG_FLOWS[@]}"; do
    local varname="RUNFLOW__${func//-/_}"
    if [[ "${!varname}" == 1 ]]; then
      invoke_verbose $func
    fi
  done
}

function step_run_cond() {
  func=$1
  local varname="RUN__${func//-/_}"
  if [[ "${!varname}" == 1 ]]; then
    invoke_verbose $func
  fi
}
# modules: end ------------------------------------------------------------------------------------

# jvm: begin --------------------------------------------------------------------------------------
function set_jdk_path() {
    local JDK_VERSION_VAR="JDK${JAVA_VERSION}"
    export JAVA_HOME="${!JDK_VERSION_VAR}"
    export PATH=$JAVA_HOME/bin:$PATH
}
function set_jvm_options() {
    export _JAVA_OPTIONS="${_JAVA_OPTIONS:-""}"

    # JVM ignores HOME and relies on getpwuid to determine home directory
    # That fails when we run self-hosted github agent under non-dynamic user
    # We need that for rootless docker to work
    if [[ "${NIXIFIED}" == 1 ]] ; then
    _JAVA_OPTIONS+=" -Duser.home=${HOME}"
    fi

    # Append Java Options tail
    #[help]- Set `JAVA_OPTIONS_TAIL` environment variable with additional Java arguments.
    _JAVA_OPTIONS+=" ${JAVA_OPTIONS_TAIL:-""}"
    # Format Java Options
    _JAVA_OPTIONS="$(echo "${_JAVA_OPTIONS}" | grep -v '#' | tr '\n' ' ' | tr -s ' ')"
}

function set_jvm_optimizations() {
    local JAVA_OPTIMIZATIONS="
    $(echo "${_JAVA_OPTIONS}" | grep -v '#' | tr '\n' ' ' | tr -s ' ')
    # JVM ignores HOME and relies on getpwuid to determine home directory
    # That fails when we run self-hosted github agent under non-dynamic user
    # We need that for rootless docker to work
    -Xmx4000M
    -XX:ReservedCodeCacheSize=384M
    -XX:NonProfiledCodeHeapSize=256M
    -XX:MaxMetaspaceSize=1024M
    "
    _JAVA_OPTIONS="$(echo "${JAVA_OPTIMIZATIONS}" | grep -v '#' | tr '\n' ' ' | tr -s ' ')"
}

function set_scala_variables() {
    [[ -z "${SCALA_VERSION+x}" ]] && echo "Missing SCALA_VERSION" && exit 1
    export VERSION_COMMAND="++ $SCALA_VERSION"
}

function set_scala_sbtgen_variables() {
    replacement="build.${CI_BUILD_UNIQ_SUFFIX}"
    export PROJECT_VERSION=$(cat version.sbt | sed -r 's/.*\"(.*)\".**/\1/' | sed -E "s/SNAPSHOT/${replacement}/")

    export SCALA212=$(cat project/Deps.sc | grep 'val scala212 ' |  sed -r 's/.*\"(.*)\".**/\1/')
    export SCALA213=$(cat project/Deps.sc | grep 'val scala213 ' |  sed -r 's/.*\"(.*)\".**/\1/')
    export SCALA3=$(cat project/Deps.sc | grep 'val scala300 ' |  sed -r 's/.*\"(.*)\".**/\1/')

    case $SCALA_VERSION in
    2.12) SCALA_VERSION="$SCALA212" ;;
    2.13) SCALA_VERSION="$SCALA213" ;;
    3) SCALA_VERSION="$SCALA3" ;;
    *) ;;
    esac

    export SCALA_VERSION="$SCALA_VERSION"
    set_scala_variables
}
# jvm: end ----------------------------------------------------------------------------------------

# github: begin ------------------------------------------------------------------------------------
function validate_publishing() {
  # Disallow if this is a pull‑request build
  if [[ "$CI_PULL_REQUEST" == "true" ]]; then
    echo "Publishing not allowed on P/Rs"
    return 1
  fi

  # Disallow if we're neither on develop nor on a tagged release (v*)
  if [[ "$CI_BRANCH" != "develop" && ! "$CI_BRANCH_TAG" =~ ^v ]]; then
    echo "Publishing not allowed (CI_BRANCH=$CI_BRANCH, CI_BRANCH_TAG=$CI_BRANCH_TAG)"
    return 1
  fi

  return 0
}

function set_gh_env() {
    export CI_BUILD_UNIQ_SUFFIX="${CI_BUILD_UNIQ_SUFFIX:-$(date +%s)}"
}
# github: end --------------------------------------------------------------------------------------

