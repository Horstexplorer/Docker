#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly DEFAULT_STACK_SELECTION='prompt'
readonly DEFAULT_UPDATE_MODE='full'
readonly PROMPT_STACK_SELECTION_DEFAULT='all'
readonly DEFAULT_CLEANUP_SELECTION='images'

declare -A PROJECT_DIRS=()
declare -A PROJECT_CONFIGS=()
declare -a DISCOVERED_STACKS=()

usage() {
  cat <<'EOF'
Usage:
  compose-mgmt.sh [--list] [--stacks all|prompt|name1,name2] [--mode full|pull-only|up|restart] [--cleanup [all|images|volumes|build-cache|containers|networks]]

Description:
  Detect Docker Compose stacks from Docker container labels and update them.

Options:
  -h, --help Show this help message
  --list     List detected stack names and exit
  --stacks   Stack selection mode:
               all                Update all detected stacks
               prompt             Show detected stacks and prompt for selection (default)
               name1,name2,...    Update only selected stack names
  --mode     Update mode:
               full               pull + up -d --remove-orphans (default)
               pull-only          Pull images only
               up                 Recreate services from current images
               restart            Restart services
  --cleanup  Prune unused Docker data targets (can be combined with updates)
             Targets: all, images, volumes, build-cache, containers, networks
             Default target: images
             Prompt stack mode applies cleanup by default after updates
             Examples: --cleanup
                       --cleanup images,build-cache
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name=$1
  command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: ${command_name}"
}

trim_ascii_whitespace() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

ensure_docker_available() {
  docker info >/dev/null 2>&1 || die 'Docker daemon is not reachable'
}

discover_compose_stacks() {
  local project_name working_dir config_files

  while IFS=$'\t' read -r project_name working_dir config_files; do
    [[ -n ${project_name} ]] || continue

    if [[ -z ${PROJECT_DIRS["$project_name"]+x} || -z ${PROJECT_DIRS["$project_name"]} ]]; then
      PROJECT_DIRS["$project_name"]=$working_dir
    fi

    if [[ -z ${PROJECT_CONFIGS["$project_name"]+x} || -z ${PROJECT_CONFIGS["$project_name"]} ]]; then
      PROJECT_CONFIGS["$project_name"]=$config_files
    fi
  done < <(docker ps -a \
    --filter 'label=com.docker.compose.project' \
    --format '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.project.working_dir"}}	{{.Label "com.docker.compose.project.config_files"}}')

  if [[ ${#PROJECT_DIRS[@]} -eq 0 ]]; then
    die 'No Docker Compose stacks were detected'
  fi

  mapfile -t DISCOVERED_STACKS < <(printf '%s\n' "${!PROJECT_DIRS[@]}" | sort)
}

prompt_stack_selection() {
  local response
  printf 'Detected stacks:\n' >&2
  printf '  %s\n' "${DISCOVERED_STACKS[@]}" >&2
  printf 'Select stacks to update [all]: ' >&2
  read -r response
  response=$(trim_ascii_whitespace "${response}")
  if [[ -z ${response} ]]; then
    printf '%s' "${PROMPT_STACK_SELECTION_DEFAULT}"
  else
    printf '%s' "${response}"
  fi
}

prompt_update_mode() {
  local response
  printf 'Select update mode [full|pull-only|up|restart] (default: full): ' >&2
  read -r response
  response=$(trim_ascii_whitespace "${response}")
  if [[ -z ${response} ]]; then
    printf '%s' "${DEFAULT_UPDATE_MODE}"
  else
    printf '%s' "${response}"
  fi
}

resolve_stack_selection() {
  local selector=$1
  local normalized_selector
  local item
  local -A selected_set=()
  local -a selected=()

  normalized_selector=$(trim_ascii_whitespace "${selector}")
  if [[ -z ${normalized_selector} ]]; then
    normalized_selector=$DEFAULT_STACK_SELECTION
  fi

  if [[ ${normalized_selector} == 'all' ]]; then
    printf '%s\n' "${DISCOVERED_STACKS[@]}"
    return 0
  fi

  if [[ ${normalized_selector} == 'prompt' ]]; then
    normalized_selector=$(prompt_stack_selection)
    if [[ ${normalized_selector} == 'all' ]]; then
      printf '%s\n' "${DISCOVERED_STACKS[@]}"
      return 0
    fi
  fi

  IFS=',' read -r -a selected <<< "${normalized_selector}"
  for item in "${selected[@]}"; do
    item=$(trim_ascii_whitespace "${item}")
    [[ -n ${item} ]] || continue

    if [[ -z ${PROJECT_DIRS["$item"]+x} ]]; then
      die "Stack not found: ${item}"
    fi

    selected_set["$item"]=1
  done

  if [[ ${#selected_set[@]} -eq 0 ]]; then
    die 'No stacks selected'
  fi

  mapfile -t selected < <(printf '%s\n' "${!selected_set[@]}" | sort)
  printf '%s\n' "${selected[@]}"
}

validate_update_mode() {
  local mode=$1
  case "$mode" in
    full|pull-only|up|restart) return 0 ;;
    *) return 1 ;;
  esac
}

validate_cleanup_target() {
  local target=$1
  case "$target" in
    all|images|volumes|build-cache|containers|networks) return 0 ;;
    *) return 1 ;;
  esac
}

build_compose_args() {
  local project_name=$1
  local working_dir config_files config_file
  local -a args=()
  local -a config_file_list=()

  working_dir=${PROJECT_DIRS["$project_name"]}
  config_files=${PROJECT_CONFIGS["$project_name"]}

  args+=(--project-name "$project_name")

  if [[ -n ${working_dir} ]]; then
    args+=(--project-directory "$working_dir")
  fi

  if [[ -n ${config_files} ]]; then
    IFS=',' read -r -a config_file_list <<< "$config_files"
    for config_file in "${config_file_list[@]}"; do
      config_file=$(trim_ascii_whitespace "${config_file}")
      [[ -n ${config_file} ]] || continue

      if [[ ${config_file} != /* && -n ${working_dir} ]]; then
        config_file="${working_dir}/${config_file}"
      fi

      args+=(-f "$config_file")
    done
  fi

  printf '%s\0' "${args[@]}"
}

run_compose() {
  local project_name=$1
  shift
  local -a compose_args=()
  local -a operation=("$@")

  mapfile -d '' -t compose_args < <(build_compose_args "$project_name")
  docker compose "${compose_args[@]}" "${operation[@]}"
}

update_stack() {
  local project_name=$1
  local mode=$2

  printf 'Updating stack: %s (mode: %s)\n' "$project_name" "$mode"

  case "$mode" in
    full)
      run_compose "$project_name" pull
      run_compose "$project_name" up -d --remove-orphans
      ;;
    pull-only)
      run_compose "$project_name" pull
      ;;
    up)
      run_compose "$project_name" up -d --remove-orphans
      ;;
    restart)
      run_compose "$project_name" restart
      ;;
    *)
      die "Unsupported update mode: ${mode}"
      ;;
  esac
}

cleanup_docker_artifacts() {
  local cleanup_selector=$1
  local target
  local -a cleanup_targets=()
  local do_images=false
  local do_volumes=false
  local do_build_cache=false
  local do_containers=false
  local do_networks=false

  IFS=',' read -r -a cleanup_targets <<< "$cleanup_selector"

  for target in "${cleanup_targets[@]}"; do
    target=$(trim_ascii_whitespace "${target}")
    [[ -n ${target} ]] || continue
    validate_cleanup_target "$target" || die "Invalid cleanup target: ${target}"

    case "$target" in
      all)
        do_images=true
        do_volumes=true
        do_build_cache=true
        do_containers=true
        do_networks=true
        ;;
      images) do_images=true ;;
      volumes) do_volumes=true ;;
      build-cache) do_build_cache=true ;;
      containers) do_containers=true ;;
      networks) do_networks=true ;;
    esac
  done

  if [[ ${do_containers} == true ]]; then
    docker container prune --force
  fi

  if [[ ${do_networks} == true ]]; then
    docker network prune --force
  fi

  if [[ ${do_images} == true ]]; then
    docker image prune --all --force
  fi

  if [[ ${do_volumes} == true ]]; then
    docker volume prune --force
  fi

  if [[ ${do_build_cache} == true ]]; then
    docker builder prune --all --force
  fi
}

main() {
  local stack_selector=$DEFAULT_STACK_SELECTION
  local update_mode=
  local argument=
  local list_only=false
  local cleanup_requested=false
  local cleanup_option_provided=false
  local cleanup_selector=$DEFAULT_CLEANUP_SELECTION
  local stacks_option_provided=false
  local mode_option_provided=false
  local -a stacks_to_update=()

  require_command docker

  while [[ $# -gt 0 ]]; do
    argument=$1
    case "$argument" in
      --stacks)
        [[ $# -ge 2 ]] || die 'Missing value for --stacks'
        stack_selector=$2
        stacks_option_provided=true
        shift 2
        ;;
      --mode)
        [[ $# -ge 2 ]] || die 'Missing value for --mode'
        update_mode=$2
        mode_option_provided=true
        shift 2
        ;;
      --list)
        list_only=true
        shift
        ;;
      --cleanup)
        cleanup_requested=true
        cleanup_option_provided=true
        if [[ $# -ge 2 && $2 != -* ]]; then
          cleanup_selector=$2
          shift 2
        else
          cleanup_selector=$DEFAULT_CLEANUP_SELECTION
          shift
        fi
        ;;
      --cleanup=*)
        cleanup_requested=true
        cleanup_option_provided=true
        cleanup_selector=${argument#--cleanup=}
        [[ -n ${cleanup_selector} ]] || die 'Missing value for --cleanup'
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: ${argument}"
        ;;
    esac
  done

  ensure_docker_available

  if [[ ${cleanup_option_provided} == false && ${stack_selector} == 'prompt' ]]; then
    cleanup_requested=true
    cleanup_selector=$DEFAULT_CLEANUP_SELECTION
  fi

  if [[ ${list_only} == false && ${cleanup_option_provided} == true && ${cleanup_requested} == true && ${stacks_option_provided} == false && ${mode_option_provided} == false ]]; then
    cleanup_docker_artifacts "$cleanup_selector"
    exit 0
  fi

  discover_compose_stacks

  if [[ ${list_only} == true ]]; then
    printf '%s\n' "${DISCOVERED_STACKS[@]}"
    exit 0
  fi

  if [[ -z ${update_mode} ]]; then
    if [[ -t 0 ]]; then
      update_mode=$(prompt_update_mode)
    else
      update_mode=$DEFAULT_UPDATE_MODE
    fi
  fi

  validate_update_mode "$update_mode" || die "Invalid update mode: ${update_mode}"

  mapfile -t stacks_to_update < <(resolve_stack_selection "$stack_selector")

  if [[ ${#stacks_to_update[@]} -eq 0 ]]; then
    die 'No stacks selected for update'
  fi

  for argument in "${stacks_to_update[@]}"; do
    update_stack "$argument" "$update_mode"
  done

  if [[ ${cleanup_requested} == true ]]; then
    cleanup_docker_artifacts "$cleanup_selector"
  fi
}

main "$@"
