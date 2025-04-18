#!/usr/bin/env bash
# shellcheck disable=SC1090

set -euo pipefail

function add_prefix() {
    local prefix="$1"
    while IFS= read -r line; do
        echo "${prefix}${line}"
    done
}

function echo-bold() {
    local bold=$(tput bold)
    local normal=$(tput sgr0)
    echo "${bold}$1${normal}"
}

function print-command-help() {
    local command="$1"
    local command_help="$2"

    local help_indent=$(printf "%*s" "${#command}" "")
    local help_head=$(echo "${command_help}" | sed -n "1p")
    local help_tail=$(echo "${command_help}" | sed -n "1!p" | add_prefix " ${help_indent}")
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

function nixify() {
    read -r -a args <<< "$(grep -v '^\s*$' $MOBALA_KEEP | grep -v '#' | sed "s/^/--keep /;s/$/ /" | tr '\n' ' ')"

    if [[ -z "${IN_NIX_SHELL+x}" ]]; then
        echo "[info] Restarting in Nix..."
        export NIXIFIED=1
        nix flake lock
        nix flake metadata
        exec nix develop \
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


# Steps: begin ------------------------------------------------------------------------------------
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
# Steps: end ------------------------------------------------------------------------------------



script_path="$(realpath "$0")"
script_dirname="$(dirname "$script_path")"

export MOBALA_PATH=${MOBALA_PATH:-"${script_dirname}"}
export MOBALA_SUBDIR_NAME=${MOBALA_SUBDIR_NAME:-".mobala"}
export MOBALA_SUBDIR=${MOBALA_SUBDIR:-"${MOBALA_PATH}/${MOBALA_SUBDIR_NAME}"}
export MOBALA_KEEP=${MOBALA_KEEP:-"${MOBALA_SUBDIR}/keep.env"}
export MOBALA_ENV=${MOBALA_ENV:-"${MOBALA_SUBDIR}/env.sh"}
export MOBALA_MODS=${MOBALA_MODS:-"${MOBALA_SUBDIR}/mods"}
export MOBALA_STEPS=${MOBALA_STEPS:-"${MOBALA_SUBDIR}/steps"}
export MOBALA_FLOWS=${MOBALA_FLOWS:-"${MOBALA_SUBDIR}/flows"}
export MOBALA_PARAMS=${MOBALA_PARAMS:-"${MOBALA_SUBDIR}/params"}

export LANG="C.UTF-8"
export NIXIFIED=${NIXIFIED:-0}
export DO_VERBOSE=${DO_VERBOSE:-0}
export VERBOSE_LEVEL=${VERBOSE_LEVEL:-0}

echo "[info] Script in '${script_path}'"
echo "[info] Working in '${MOBALA_PATH}'."
cd "$MOBALA_PATH"

# parse command line and execute modes
idx=0
arguments=("$@")
arguments_length="${#arguments[@]}"
while [[ $idx -lt $arguments_length ]] ; do
    arg="${arguments[idx]}"
    case "$arg" in
        --nix)
          idx=$((idx+1))
          shift && nixify "$@"
          ;;

        --help)
          idx=$((idx+1))
          print-help
          exit 0
          ;;

        -v|--verbose)
          idx=$((idx+1))
          set -x
          export DO_VERBOSE=1
          export VERBOSE_LEVEL=1
          ;;

        -vv|--very-verbose)
          idx=$((idx+1))
          set -x
          export DO_VERBOSE=1
          export VERBOSE_LEVEL=2
          ;;

        -e|--env)
          local arg="${arguments[$((idx+1))]}"
          idx=$((idx+2))
          export "$(echo "${arg}" | xargs)"
          ;;

        --*=*)
          idx=$((idx+1))

          # set build parameter
          build_param=$(echo "${arg:2}" | cut -d "=" -f 1)
          build_arg=$(echo "${arg:2}" | cut -d "=" -f 2)
          if [[ -f "${MOBALA_PARAMS}/$build_param.sh" ]]; then
              echo "[info] Setting build parameter: $build_param=$build_arg"
              function run-param() { source "${MOBALA_PARAMS}/$build_param.sh" $build_arg ; } ; run-param
          fi
          ;;

        --*)
          idx=$((idx+1))

          # apply build parameter
          local build_param="${arg:2}"
          if [[ -f "${MOBALA_PARAMS}/$build_param.sh" ]]; then
              echo "[info] Applying build parameter: $build_param"
              function run-param() { source "${MOBALA_PARAMS}/$build_param.sh" ; } ; run-param
          fi
          ;;

        :*)
            idx=$((idx+1))

            # parse build mode arguments
            local build_mode="${arg:1}"
            local build_mode_args=()
            while [[ $idx -lt $arguments_length ]] && ! [[ "${arguments[idx]}" =~ ^:.* ]] ; do
                build_mode_args+=("${arguments[idx]}")
                idx=$((idx+1))
            done

            # run build mode
            if [[ -f "${MOBALA_MODS}/$build_mode.sh" ]]; then
                echo "[info] Applying mode $build_mode: '${MOBALA_MODS}/$build_mode.sh ${build_mode_args[*]}'"
                function run-mode() { source "${MOBALA_MODS}/$build_mode.sh" "${build_mode_args[@]}" ; } ; run-mode
            else
                echo "[info] There is no launcher file for $build_mode, activating step run-${build_mode}"
                step_enable "run-${build_mode}"
            fi
            ;;

        *)
            idx=$((idx+1))
            ;;
    esac
done

{ echo "Done processing arguments" ; } 2>/dev/null

source "${MOBALA_ENV}" $*

invoke_quiet steps_register
invoke_quiet flows_register
invoke_quiet steps_report
invoke_quiet flows_run
