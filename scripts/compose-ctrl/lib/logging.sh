LOG_COLOR_RESET="${LOG_COLOR_RESET:-}"
LOG_COLOR_WARN="${LOG_COLOR_WARN:-}"
LOG_COLOR_ERROR="${LOG_COLOR_ERROR:-}"

init_log_style() {
  LOG_COLOR_RESET=''
  LOG_COLOR_WARN=''
  LOG_COLOR_ERROR=''

  if [[ "${LOG_FORCE_NO_COLOR:-0}" -eq 1 || -n "${NO_COLOR:-}" ]]; then
    return
  fi

  if [[ -t 1 || -t 2 ]]; then
    LOG_COLOR_RESET='\033[0m'
    LOG_COLOR_WARN='\033[1;33m'
    LOG_COLOR_ERROR='\033[1;31m'
  fi
}

log_base() {
  local level="${1:-}"
  local color="${2:-}"
  local stream="${3:-stdout}"
  shift 3

  if [[ -z "$level" ]]; then
    if [[ "$stream" == "stderr" ]]; then
      printf '%s\n' "$*" >&2
    else
      printf '%s\n' "$*"
    fi
    return
  fi

  if [[ "$stream" == "stderr" ]]; then
    printf '%b%-5s%b %s\n' "$color" "$level" "$LOG_COLOR_RESET" "$*" >&2
  else
    printf '%b%-5s%b %s\n' "$color" "$level" "$LOG_COLOR_RESET" "$*"
  fi
}

log_info() {
  if [[ "${LOG_VERBOSE:-0}" -ne 1 && "${LOG_QUIET:-0}" -eq 1 ]]; then
    return
  fi
  log_base '' '' 'stdout' "$*"
}

log_warn() {
  log_base 'WARN' "$LOG_COLOR_WARN" 'stderr' "$*"
}

log_error() {
  log_base 'ERROR' "$LOG_COLOR_ERROR" 'stderr' "$*"
}

log_section() {
  if [[ "${LOG_QUIET:-0}" -eq 1 ]]; then
    return
  fi
  printf -- '----- %s -----\n' "$*"
}
