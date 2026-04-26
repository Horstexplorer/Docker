#!/usr/bin/env bash
set -Eeuo pipefail

LOG_QUIET=0
LOG_FORCE_NO_COLOR=0
CHECK_OFFLINE=0
LOG_VERBOSE=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

LOG_LIB_PATH="${LIB_DIR}/logging.sh"
if [[ ! -f "$LOG_LIB_PATH" ]]; then
  printf 'ERROR missing logging library: %s\n' "$LOG_LIB_PATH" >&2
  exit 1
fi
# shellcheck source=lib/logging.sh
source "$LOG_LIB_PATH"

SPINNER_LIB_PATH="${LIB_DIR}/spinner.sh"
if [[ ! -f "$SPINNER_LIB_PATH" ]]; then
  printf 'ERROR missing spinner library: %s\n' "$SPINNER_LIB_PATH" >&2
  exit 1
fi
# shellcheck source=lib/spinner.sh
source "$SPINNER_LIB_PATH"


usage() {
  local script_name
  script_name="$0"

  cat <<EOF
Manage deployed Docker Compose stacks.

Usage:
  ${script_name} <command> [options]

Commands:
  list                 List deployed stacks and check image drift
  check                Show per-stack container image drift
  pull                 Pull latest images for stacks
  refresh              Stop stack, pull images, and start stack again

Options:
  -h, --help           Show this help
  -a, --all            Target all deployed stacks
  -s, --stack NAME     Restrict command to a single stack (can be used multiple times)
      --offline        Skip remote registry checks and only use local image state for list/check
  -q, --quiet          Reduce non-critical log output (keeps warnings/errors)
      --no-color       Disable color output
      --verbose        Show detailed logs instead of spinner progress

EOF
}

require_cmds() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error 'Required command missing: docker'
    exit 127
  fi
}

json_get_string() {
  local json_obj="$1"
  local key="$2"

  local value
  value="$(printf '%s' "$json_obj" | sed -n "s/.*\"$key\":\"\([^\"]*\)\".*/\1/p")"
  value="${value//\\\//\/}"
  value="${value//\\\\/\\}"
  value="${value//\\\"/\"}"
  printf '%s' "$value"
}

json_array_objects() {
  tr -d '\n' | sed -e 's/^\[//' -e 's/\]$//' -e 's/},{/}\n{/g'
}

trim() {
  local val="$1"
  # Trim leading and trailing whitespace.
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  printf '%s' "$val"
}

parse_compose_files() {
  local raw="$1"
  local -n out_ref="$2"
  out_ref=()

  local file
  IFS=',' read -r -a file_list <<<"$raw"
  for file in "${file_list[@]}"; do
    file="$(trim "$file")"
    if [[ -n "$file" ]]; then
      out_ref+=("-f" "$file")
    fi
  done
}

compose_stack() {
  local stack_name="$1"
  local config_files_raw="$2"
  shift 2

  local -a compose_files
  parse_compose_files "$config_files_raw" compose_files

  docker compose -p "$stack_name" "${compose_files[@]}" "$@"
}

stack_selected() {
  local name="$1"
  shift

  if [[ "$#" -eq 0 ]]; then
    return 0
  fi

  local selected
  for selected in "$@"; do
    if [[ "$selected" == "$name" ]]; then
      return 0
    fi
  done

  return 1
}

collect_selected_stacks() {
  local -n out_names_ref="$1"
  local -n out_status_ref="$2"
  local -n out_cfg_ref="$3"
  shift 3

  local -a selected_stacks=("$@")
  out_names_ref=()
  out_status_ref=()
  out_cfg_ref=()

  local name status cfg_raw
  while IFS=$'\t' read -r name status cfg_raw; do
    [[ -z "$name" ]] && continue
    if ! stack_selected "$name" "${selected_stacks[@]}"; then
      continue
    fi

    out_names_ref+=("$name")
    out_status_ref+=("$status")
    out_cfg_ref+=("$cfg_raw")
  done < <(list_stacks_raw)
}

list_stacks_raw() {
  local obj name status cfg

  while IFS= read -r obj; do
    [[ -z "$obj" ]] && continue
    name="$(json_get_string "$obj" 'Name')"
    status="$(json_get_string "$obj" 'Status')"
    cfg="$(json_get_string "$obj" 'ConfigFiles')"

    [[ -z "$name" ]] && continue
    printf '%s\t%s\t%s\n' "$name" "$status" "$cfg"
  done < <(docker compose ls --all --format json | json_array_objects)
}

list_stack_containers_raw() {
  local stack_name="$1"
  local cfg_raw="$2"

  local cid service image state
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    service="$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$cid" 2>/dev/null || true)"
    image="$(docker inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null || true)"
    state="$(docker inspect --format '{{.State.Status}}' "$cid" 2>/dev/null || true)"
    printf '%s\t%s\t%s\t%s\n' "$cid" "$service" "$image" "$state"
  done < <(compose_stack "$stack_name" "$cfg_raw" ps --all -q 2>/dev/null || true)
}

container_has_pending_update() {
  local cid="$1"
  local image="$2"

  local container_image_id local_image_id
  IFS=$'\t' read -r container_image_id local_image_id < <(container_image_ids "$cid" "$image")

  if [[ -n "$container_image_id" && -n "$local_image_id" && "$container_image_id" != "$local_image_id" ]]; then
    return 0
  fi

  return 1
}

container_image_ids() {
  local cid="$1"
  local image="$2"

  local container_image_id local_image_id
  container_image_id="$(docker inspect --format '{{.Image}}' "$cid" 2>/dev/null || true)"
  local_image_id="$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)"

  printf '%s\t%s\n' "$container_image_id" "$local_image_id"
}

short_sha() {
  local id="$1"

  if [[ -z "$id" ]]; then
    printf 'unknown'
    return
  fi

  id="${id#sha256:}"
  printf '%.12s' "$id"
}

count_running_and_total() {
  local stack_name="$1"
  local cfg_raw="$2"

  local running=0
  local total=0
  local cid _service _image state

  while IFS=$'\t' read -r cid _service _image state; do
    [[ -z "$cid" ]] && continue
    total=$((total + 1))
    if [[ "$state" == "running" ]]; then
      running=$((running + 1))
    fi
  done < <(list_stack_containers_raw "$stack_name" "$cfg_raw" 2>/dev/null || true)

  printf '%s/%s' "$running" "$total"
}

stack_update_details() {
  local stack_name="$1"
  local cfg_raw="$2"

  local cid service image _state
  local container_name display_name container_image_id local_image_id
  local old_sha new_sha

  while IFS=$'\t' read -r cid service image _state; do
    [[ -z "$cid" || -z "$image" ]] && continue

    if container_has_pending_update "$cid" "$image"; then
      container_name="$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null || true)"
      container_name="${container_name#/}"
      IFS=$'\t' read -r container_image_id local_image_id < <(container_image_ids "$cid" "$image")
      old_sha="$(short_sha "$container_image_id")"
      new_sha="$(short_sha "$local_image_id")"

      [[ -z "$service" ]] && service='unknown'
      [[ -z "$image" ]] && image='unknown'

      if [[ -n "$container_name" ]]; then
        display_name="$container_name"
      elif [[ -n "$service" ]]; then
        display_name="$service"
      else
        display_name="$cid"
      fi

      printf '    %-32s %-20s %-40s %-12s %-12s\n' "$display_name" "$service" "$image" "$old_sha" "$new_sha"
    fi
  done < <(list_stack_containers_raw "$stack_name" "$cfg_raw" 2>/dev/null || true)
}

stack_has_pending_updates() {
  local stack_name="$1"
  local cfg_raw="$2"

  if [[ "$(stack_pending_update_count "$stack_name" "$cfg_raw")" -gt 0 ]]; then
    return 0
  fi

  return 1
}

stack_pending_update_count() {
  local stack_name="$1"
  local cfg_raw="$2"

  local cid _service image _state
  local count=0

  while IFS=$'\t' read -r cid _service image _state; do
    [[ -z "$cid" || -z "$image" ]] && continue

    if container_has_pending_update "$cid" "$image"; then
      count=$((count + 1))
    fi
  done < <(list_stack_containers_raw "$stack_name" "$cfg_raw" 2>/dev/null || true)

  printf '%s' "$count"
}

sync_check_images_from_registry() {
  local -n stack_names_ref="$1"
  local -n stack_cfgs_ref="$2"

  if [[ "$LOG_VERBOSE" -eq 1 ]]; then
    sync_check_images_from_registry_impl "$1" "$2"
    return
  fi

  spinner_run 'Checking remote registries...' 1 sync_check_images_from_registry_impl "$1" "$2"
}

sync_check_images_from_registry_impl() {
  local -n stack_names_ref="$1"
  local -n stack_cfgs_ref="$2"

  local pulled_images=$'\n'
  local i cid _service image _state

  for ((i = 0; i < ${#stack_names_ref[@]}; i++)); do
    while IFS=$'\t' read -r cid _service image _state; do
      [[ -z "$cid" || -z "$image" ]] && continue

      # Digest-pinned references are immutable and have no moving tag to compare remotely.
      if [[ "$image" == *@* ]]; then
        continue
      fi

      if [[ "$pulled_images" == *$'\n'"$image"$'\n'* ]]; then
        continue
      fi
      pulled_images+="$image"$'\n'

      if [[ "$LOG_VERBOSE" -eq 1 ]]; then
        log_info "Checking remote image tag: $image"
      fi
      if ! docker pull "$image" >/dev/null 2>&1; then
        log_warn "Could not check remote registry for image: $image"
      fi
    done < <(list_stack_containers_raw "${stack_names_ref[i]}" "${stack_cfgs_ref[i]}" 2>/dev/null || true)
  done
}

pull_stack() {
  local stack_name="$1"
  local cfg_raw="$2"

  if [[ "$LOG_VERBOSE" -eq 1 ]]; then
    log_info "Pulling latest images for stack: ${stack_name}"
  fi

  compose_stack "$stack_name" "$cfg_raw" pull
}

refresh_stack() {
  local stack_name="$1"
  local cfg_raw="$2"

  if [[ "$LOG_VERBOSE" -eq 1 ]]; then
    log_info "Stopping stack: ${stack_name}"
  fi
  compose_stack "$stack_name" "$cfg_raw" stop

  if [[ "$LOG_VERBOSE" -eq 1 ]]; then
    log_info "Pulling latest images: ${stack_name}"
  fi
  compose_stack "$stack_name" "$cfg_raw" pull

  if [[ "$LOG_VERBOSE" -eq 1 ]]; then
    log_info "Starting stack: ${stack_name}"
  fi
  compose_stack "$stack_name" "$cfg_raw" up -d
}

cmd_list() {
  local -a selected_stacks=("$@")
  local -a stack_names=()
  local -a stack_statuses=()
  local -a stack_cfgs=()

  collect_selected_stacks stack_names stack_statuses stack_cfgs "${selected_stacks[@]}"

  if [[ "$CHECK_OFFLINE" -ne 1 ]]; then
    sync_check_images_from_registry stack_names stack_cfgs
  fi

  printf '%-24s %-24s %-12s %-10s\n' 'STACK' 'STATUS' 'CONTAINERS' 'UPDATES'
  printf '%-24s %-24s %-12s %-10s\n' '-----' '------' '----------' '-------'

  local i container_ratio update_state
  for ((i = 0; i < ${#stack_names[@]}; i++)); do
    container_ratio="$(count_running_and_total "${stack_names[i]}" "${stack_cfgs[i]}")"
    if stack_has_pending_updates "${stack_names[i]}" "${stack_cfgs[i]}"; then
      update_state='yes'
    else
      update_state='no'
    fi

    printf '%-24s %-24s %-12s %-10s\n' "${stack_names[i]}" "${stack_statuses[i]}" "$container_ratio" "$update_state"
  done
}

cmd_check() {
  local -a selected_stacks=("$@")
  local -a stack_names=()
  local -a _stack_statuses=()
  local -a stack_cfgs=()
  local -a update_stack_names=()
  local -a update_stack_cfgs=()

  collect_selected_stacks stack_names _stack_statuses stack_cfgs "${selected_stacks[@]}"

  if [[ "$CHECK_OFFLINE" -ne 1 ]]; then
    sync_check_images_from_registry stack_names stack_cfgs
  fi

  local i update_count
  for ((i = 0; i < ${#stack_names[@]}; i++)); do
    update_count="$(stack_pending_update_count "${stack_names[i]}" "${stack_cfgs[i]}")"
    if [[ "$update_count" -gt 0 ]]; then
      update_stack_names+=("${stack_names[i]}")
      update_stack_cfgs+=("${stack_cfgs[i]}")
    fi
  done

  if [[ "${#stack_names[@]}" -eq 0 ]]; then
    log_warn 'No matching deployed stacks found.'
    return
  fi

  if [[ "${#update_stack_names[@]}" -eq 0 ]]; then
    log_info 'No pending updates found.'
    return
  fi

  log_section 'Affected containers by stack'
  local i
  for ((i = 0; i < ${#update_stack_names[@]}; i++)); do
    printf '%s\n' "  ${update_stack_names[i]}"
    printf '    %-32s %-20s %-40s %-12s %-12s\n' 'CONTAINER' 'SERVICE' 'IMAGE' 'OLD_SHA' 'NEW_SHA'
    printf '    %-32s %-20s %-40s %-12s %-12s\n' '---------' '-------' '-----' '-------' '-------'
    stack_update_details "${update_stack_names[i]}" "${update_stack_cfgs[i]}" || true
  done
}

cmd_pull() {
  local -a selected_stacks=("$@")
  local -a stack_names=()
  local -a _stack_statuses=()
  local -a stack_cfgs=()

  collect_selected_stacks stack_names _stack_statuses stack_cfgs "${selected_stacks[@]}"

  local i
  for ((i = 0; i < ${#stack_names[@]}; i++)); do
    if [[ "$LOG_VERBOSE" -eq 1 ]]; then
      pull_stack "${stack_names[i]}" "${stack_cfgs[i]}"
    else
      spinner_run "Pulling latest images for stack: ${stack_names[i]}" 0 pull_stack "${stack_names[i]}" "${stack_cfgs[i]}"
    fi
  done

  if [[ "${#stack_names[@]}" -eq 0 ]]; then
    log_warn 'No matching deployed stacks found.'
  fi
}

cmd_refresh() {
  local -a selected_stacks=("$@")
  local -a stack_names=()
  local -a _stack_statuses=()
  local -a stack_cfgs=()

  collect_selected_stacks stack_names _stack_statuses stack_cfgs "${selected_stacks[@]}"

  local i
  for ((i = 0; i < ${#stack_names[@]}; i++)); do
    if [[ "$LOG_VERBOSE" -eq 1 ]]; then
      refresh_stack "${stack_names[i]}" "${stack_cfgs[i]}"
    else
      spinner_run "Refreshing stack: ${stack_names[i]}" 0 refresh_stack "${stack_names[i]}" "${stack_cfgs[i]}"
    fi
  done

  if [[ "${#stack_names[@]}" -eq 0 ]]; then
    log_warn 'No matching deployed stacks found.'
  fi
}

require_explicit_stack_scope() {
  local command_name="$1"
  local all_selected="$2"
  local selected_count="$3"

  if [[ "$all_selected" -ne 1 && "$selected_count" -eq 0 ]]; then
    log_error "$command_name requires --all or --stack."
    return 1
  fi

  return 0
}

main() {
  if [[ "$#" -eq 0 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    -h|--help|help)
      usage
      exit 0
      ;;
  esac

  local -a selected_stacks=()
  local all_selected=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s|--stack)
        if [[ "$#" -lt 2 ]]; then
          log_error 'Missing value for --stack'
          exit 2
        fi
        selected_stacks+=("$2")
        shift 2
        ;;
      -a|--all)
        all_selected=1
        shift
        ;;
      --offline)
        CHECK_OFFLINE=1
        shift
        ;;
      --verbose)
        LOG_VERBOSE=1
        shift
        ;;
      -q|--quiet)
        # shellcheck disable=SC2034
        LOG_QUIET=1
        shift
        ;;
      --no-color)
        # shellcheck disable=SC2034
        LOG_FORCE_NO_COLOR=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 2
        ;;
    esac
  done

  if [[ "$all_selected" -eq 1 && "${#selected_stacks[@]}" -gt 0 ]]; then
    log_error 'Use either --all or --stack, not both.'
    exit 2
  fi

  init_log_style
  require_cmds

  case "$command" in
    list)
      cmd_list "${selected_stacks[@]}"
      ;;
    check)
      require_explicit_stack_scope 'check' "$all_selected" "${#selected_stacks[@]}" || exit 2
      cmd_check "${selected_stacks[@]}"
      ;;
    pull)
      require_explicit_stack_scope 'pull' "$all_selected" "${#selected_stacks[@]}" || exit 2
      cmd_pull "${selected_stacks[@]}"
      ;;
    refresh)
      require_explicit_stack_scope 'refresh' "$all_selected" "${#selected_stacks[@]}" || exit 2
      cmd_refresh "${selected_stacks[@]}"
      ;;
    *)
      log_error "Unknown command: $command"
      usage
      exit 2
      ;;
  esac
}

main "$@"
