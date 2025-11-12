#!/usr/bin/env bash
# shellcheck disable=SC1090

set -euo pipefail

script_path="$(realpath "$0")"
script_dirname="$(dirname "$script_path")"
# mobala_dirname="$(dirname "$BASH_SOURCE")"
echo "[info] Library in '${script_dirname}/mobala-lib.sh'"
echo "[info] Script in '${script_path}'"

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
export VERBOSE_LEVEL=${VERBOSE_LEVEL:-0}

source "${script_dirname}/mobala-lib.sh"

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

        --nix=*)
          dev_shell="${arg#--nix=}"
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
