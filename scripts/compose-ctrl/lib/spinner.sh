SPINNER_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_LIB_PATH="${SPINNER_LIB_DIR}/logging.sh"
if [[ ! -f "$LOG_LIB_PATH" ]]; then
  printf 'ERROR missing logging library: %s\n' "$LOG_LIB_PATH" >&2
  return 1 2>/dev/null || exit 1
fi
# shellcheck source=logging.sh
source "$LOG_LIB_PATH"

supports_utf8_locale() {
  local locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
  local locale_upper="${locale^^}"

  [[ "$locale_upper" == *"UTF-8"* || "$locale_upper" == *"UTF8"* ]]
}

spinner_run() {
  local message="$1"
  local show_output_on_success="$2"
  shift 2

  if [[ "${LOG_VERBOSE:-0}" -eq 1 || "${LOG_QUIET:-0}" -eq 1 || ! -t 2 ]]; then
    "$@"
    return
  fi

  local tmpfile pid rc i frame start_ts now_ts elapsed
  local -a frames

  if supports_utf8_locale; then
    frames=('⣾⣷' '⣽⣯' '⣻⣟' '⢿⡿' '⣟⣻' '⣯⣽' '⣷⣾' '⡿⢿')
  else
    frames=('|' '/' '-' '\\')
  fi

  tmpfile="$(mktemp)"
  "$@" >"$tmpfile" 2>&1 &
  pid=$!
  start_ts="$(date +%s)"

  i=0
  while kill -0 "$pid" 2>/dev/null; do
    frame="${frames[$((i % ${#frames[@]}))]}"
    now_ts="$(date +%s)"
    elapsed=$((now_ts - start_ts))
    printf '\r%s %3ss: %s' "$frame" "$elapsed" "$message">&2
    sleep 0.1
    i=$((i + 1))
  done

  wait "$pid"
  rc=$?
  printf '\r\033[K' >&2

  if [[ "$rc" -eq 0 ]]; then
    log_info "$message"
  else
    log_error "$message"
  fi

  if [[ "$rc" -ne 0 || "$show_output_on_success" -eq 1 ]]; then
    if [[ -s "$tmpfile" ]]; then
      cat "$tmpfile" >&2
    fi
  fi

  rm -f "$tmpfile"
  return "$rc"
}
