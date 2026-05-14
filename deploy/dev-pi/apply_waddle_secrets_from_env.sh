#!/usr/bin/env bash
# Load apps/waddle_display/.env.development (or path you pass) and apply the same
# SecretStore + config keys as debug startup (see lib/config/dev_dotenv_secrets.dart).
#
# Usage:
#   ./deploy/dev-pi/apply_waddle_secrets_from_env.sh
#   ./deploy/dev-pi/apply_waddle_secrets_from_env.sh /path/to/.env
#   ./deploy/dev-pi/apply_waddle_secrets_from_env.sh /path/to/.env /path/to/waddle_view.sqlite
#
# Remote host: use apply_waddle_secrets_remote.sh (scp + ssh) from the same directory.
#
# Requires: Linux, secret-tool, waddlectl on PATH (same as running waddlectl locally).
# Env: WADDLECTL (default waddlectl), WADDLE_SQLITE (default path below if arg2 unset).
set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  echo 'error: bash 4+ required (declare -A)' >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_ENV="$CANDIDATE_REPO/apps/waddle_display/.env.development"

ENV_FILE="${1:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$DEFAULT_ENV" ]]; then
    ENV_FILE="$DEFAULT_ENV"
  else
    echo "error: specify ENV_FILE (default missing: $DEFAULT_ENV)" >&2
    exit 1
  fi
fi
DB="${2:-${WADDLE_SQLITE:-$HOME/.local/share/com.waddleview.waddle_display/waddle_view.sqlite}}"
WADDLECTL="${WADDLECTL:-waddlectl}"
W=( "$WADDLECTL" --database="$DB" )

if ! command -v "$WADDLECTL" >/dev/null 2>&1; then
  echo "error: $WADDLECTL not on PATH" >&2
  exit 1
fi
if [[ ! -f "$DB" ]]; then
  echo "error: database not found: $DB" >&2
  exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: env file not found: $ENV_FILE" >&2
  exit 1
fi

declare -A A=()
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw//$'\r'/}"
  line="${line#"${line%%[![:space:]]*}"}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" != *"="* ]] && continue
  k="${line%%=*}"
  v="${line#*=}"
  k="${k%"${k##*[![:space:]]}"}"
  k="${k#"${k%%[![:space:]]*}"}"
  [[ -z "$k" ]] && continue
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  if [[ "$v" == '"'*'"' && "${#v}" -ge 2 ]]; then
    v="${v:1:${#v}-2}"
  fi
  A["$k"]="$v"
done <"$ENV_FILE"

get() {
  local key="$1"
  local out="${A[$key]-}"
  printf '%s' "${out//$'\r'/}"
}

jokes_token() {
  local j
  j="$(get WADDLE_JOKES_ACCESS_TOKEN)"
  if [[ -n "${j// }" ]]; then
    printf '%s' "$j"
    return
  fi
  j="$(get OPENAI_API_KEY)"
  printf '%s' "$j"
}

trivia_token() {
  local t
  t="$(get WADDLE_TRIVIA_ACCESS_TOKEN)"
  if [[ -n "${t// }" ]]; then
    printf '%s' "$t"
    return
  fi
  jokes_token
}

pexels_token() {
  local p
  p="$(get WADDLE_PEXELS_ACCESS_TOKEN)"
  if [[ -n "${p// }" ]]; then
    printf '%s' "$p"
    return
  fi
  printf '%s' "$(get PEXELS_API_KEY)"
}

stocks_token() {
  local s
  s="$(get WADDLE_STOCKS_ACCESS_TOKEN)"
  if [[ -n "${s// }" ]]; then
    printf '%s' "$s"
    return
  fi
  printf '%s' "$(get FINNHUB_API_KEY)"
}

flickr_token() {
  local f
  f="$(get WADDLE_FLICKR_ACCESS_TOKEN)"
  if [[ -n "${f// }" ]]; then
    printf '%s' "$f"
    return
  fi
  printf '%s' "$(get FLICKR_API_KEY)"
}

set_token_if_non_empty() {
  local provider_id="$1"
  local token="$2"
  if [[ -z "${token// }" ]]; then
    return
  fi
  printf '%s' "$token" | "${W[@]}" providers set-access-token "$provider_id"
}

set_secret_if_non_empty() {
  local key="$1"
  local val="$2"
  if [[ -z "${val// }" ]]; then
    return
  fi
  printf '%s' "$val" | "${W[@]}" secrets set "$key"
}

echo "Using env file: $ENV_FILE"
echo "Using database:  $DB"

set_token_if_non_empty jokes "$(jokes_token)"
set_token_if_non_empty trivia "$(trivia_token)"
set_token_if_non_empty weather "$(get OPEN_WEATHER_MAP_API_KEY)"
set_token_if_non_empty pexels "$(pexels_token)"
set_token_if_non_empty stocks "$(stocks_token)"
set_token_if_non_empty flickr_media "$(flickr_token)"

for k in "${!A[@]}"; do
  if [[ "$k" == WADDLE_MSGRAPH_ACCESS_TOKEN_* ]]; then
    account="${k#WADDLE_MSGRAPH_ACCESS_TOKEN_}"
    account="${account#"${account%%[![:space:]]*}"}"
    account="${account%"${account##*[![:space:]]}"}"
    [[ -z "$account" ]] && continue
    v="$(get "$k")"
    set_secret_if_non_empty "provider:access_token:microsoft_graph:$account" "$v"
    rk="WADDLE_MSGRAPH_REFRESH_TOKEN_$account"
    rv="$(get "$rk")"
    set_secret_if_non_empty "provider:refresh_token:microsoft_graph:$account" "$rv"
  fi
done

for k in "${!A[@]}"; do
  if [[ "$k" == WADDLE_GOOGLE_ACCESS_TOKEN_* ]]; then
    account="${k#WADDLE_GOOGLE_ACCESS_TOKEN_}"
    account="${account#"${account%%[![:space:]]*}"}"
    account="${account%"${account##*[![:space:]]}"}"
    [[ -z "$account" ]] && continue
    v="$(get "$k")"
    set_secret_if_non_empty "provider:access_token:google:$account" "$v"
    rk="WADDLE_GOOGLE_REFRESH_TOKEN_$account"
    rv="$(get "$rk")"
    set_secret_if_non_empty "provider:refresh_token:google:$account" "$rv"
  fi
done

mg="$(get MICROSOFT_GRAPH_CLIENT_ID)"
[[ -n "${mg// }" ]] && "${W[@]}" config set microsoft.graph.client_id "$mg"
gc="$(get GOOGLE_CLIENT_ID)"
[[ -n "${gc// }" ]] && "${W[@]}" config set google.client_id "$gc"

echo 'Done.'
