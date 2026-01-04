#!/bin/bash
set -e

function ensure_command_available() {
  if ! command -v "$@" >/dev/null 2>&1
  then
    # shellcheck disable=SC2145
    echo "Command '$@' is required but not available"
    exit 1
  fi
}

ensure_command_available docker compose
ensure_command_available jq

function get_compose_json_by_name() {
  echo docker compose ls --format json | jq -r ".[] | select(.Name == '$1')"
}

compose_stacks=$(docker compose ls --format json | jq)
