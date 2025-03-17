#!/usr/bin/env bash
# shellcheck disable=SC1090

set -euo pipefail

self="$(realpath "$0")"
path="$(dirname "$self")"
echo "[info] Working in $path"
cd "$path"

export MOBALA_KEEP=${MOBALA_SOURCES:-"$(pwd)/.keep.env"}
export MOBALA_ENV=${MOBALA_SOURCES:-"$(pwd)/devops/env.sh"}
export MOBALA_MODS=${MOBALA_SOURCES:-"$(pwd)/devops/mods"}
export MOBALA_PARAMS=${MOBALA_SOURCES:-"$(pwd)/devops/params"}

export LANG="C.UTF-8"
export NIXIFIED=${NIXIFIED:-0}
export DO_VERBOSE=${DO_VERBOSE:-0}

function add_prefix() {
    prefix="$1"
    while IFS= read -r line; do
        echo "${prefix}${line}"
    done
}

function echo-bold() {
    bold=$(tput bold)
    normal=$(tput sgr0)
    echo "${bold}$1${normal}"
}

function print-command-help() {
    command="$1"
    command_help="$2"

    help_indent=$(printf "%*s" "${#command}" "")
    help_head=$(echo "${command_help}" | sed -n "1p")
    help_tail=$(echo "${command_help}" | sed -n "1!p" | add_prefix " ${help_indent}")
    echo "$(echo-bold $command) ${help_head}"
    if [[ "${help_tail}" != "" ]]; then
      echo "${help_tail}"
    fi
    echo
}

function print-help() {
    echo "Mobala bash runner!"

    if [[ -f "${MOBALA_ENV}" ]]; then
        echo-bold "Mobala environment (${MOBALA_ENV}):"
        env_help=$(cat "${MOBALA_ENV}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
        echo "${env_help}"
        echo
    fi

    echo-bold "Mobala parameters (${MOBALA_PARAMS}):"
    print-command-help "--nix" "Nixify runner commands."
    print-command-help "--verbose|-v" "Enable verbose logging for runner commands."
    print-command-help "--env|--e" 'Specify environment variable. Usage `-e PARAM=test`.'
    if [[ -d "${MOBALA_PARAMS}" ]]; then
        params=($(ls -f $MOBALA_PARAMS | sort | grep ".sh" || true))
        for param in "${params[@]}"; do
            param_name="${param::-3}"
            param_help=$(cat "${MOBALA_PARAMS}/${param}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
            print-command-help "--${param_name}" "${param_help}"
        done
    fi

    if [[ -d "${MOBALA_MODS}" ]]; then
        echo-bold "Mobala modes (${MOBALA_MODS}):"
        mods=($(ls -f $MOBALA_MODS | sort | grep ".sh" || true))
        for mode in "${mods[@]}"; do
            mode_name="${mode::-3}"
            mode_help=$(cat "${MOBALA_MODS}/${mode}" | grep "#\[help\]" | sed -r 's/^#\[help\](.*)/\1/' || true)
            print-command-help ":${mode_name}" "${mode_help}"
        done
    fi
}

function nixify() {
    read -r -a args <<< "$(grep -v '^\s*$' .keep.env | grep -v '#' | sed "s/^/--keep /;s/$/ /" | tr '\n' ' ')"

    if [[ -z "${IN_NIX_SHELL+x}" ]]; then
        echo "[info] Restarting in Nix..."
        export NIXIFIED=1
        nix flake lock
        nix flake metadata
        exec nix develop \
          --ignore-environment \
          --keep HOME \
          --keep NIXIFIED \
          --keep DO_VERBOSE \
          --keep CI \
          --keep CI_BRANCH \
          --keep CI_COMMIT \
          --keep CI_BRANCH_TAG \
          --keep CI_PULL_REQUEST \
          --keep CI_BUILD_UNIQ_SUFFIX \
          "${args[@]}" \
          --command bash "$self" "$@"
    fi
}

function mobala() {
    # parse command line and execute modes
    idx=0
    arguments=("$@")
    arguments_length="${#arguments[@]}"
    while [[ $idx -lt $arguments_length ]] ; do
        arg="${arguments[idx]}"
        case "$arg" in
            nix|--nix)
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
              ;;

            -e|--env)
              arg="${arguments[$((idx+1))]}"
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
              build_param="${arg:2}"
              if [[ -f "${MOBALA_PARAMS}/$build_param.sh" ]]; then
                  echo "[info] Applying build parameter: $build_param"
                  function run-param() { source "${MOBALA_PARAMS}/$build_param.sh" ; } ; run-param
              fi
              ;;

            :*)
                idx=$((idx+1))

                # parse build mode arguments
                build_mode="${arg:1}"
                build_mode_args=()
                while [[ $idx -lt $arguments_length ]] && ! [[ "${arguments[idx]}" =~ ^:.* ]] ; do
                    build_mode_args+=("${arguments[idx]}")
                    idx=$((idx+1))
                done

                # run build mode
                if [[ -f "${MOBALA_MODS}/$build_mode.sh" ]]; then
                    echo "[info] Applying mode $build_mode: '${MOBALA_MODS}/$build_mode.sh ${build_mode_args[*]}'"
                    function run-mode() { source "${MOBALA_MODS}/$build_mode.sh" "${build_mode_args[@]}" ; } ; run-mode
                fi
                ;;

            *)
                idx=$((idx+1))
                ;;
        esac
    done
}

# source default environment
source "${MOBALA_ENV}"

# run build
run