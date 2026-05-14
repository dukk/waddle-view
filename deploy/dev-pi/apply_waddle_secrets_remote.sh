#!/usr/bin/env bash
# Copy .env + apply_waddle_secrets_from_env.sh to the remote host over SSH,
# run the apply script, then delete the temp copies on the remote.
#
# Usage (from repo root or anywhere):
#   bash deploy/dev-pi/apply_waddle_secrets_remote.sh user@10.2.0.10
#   bash deploy/dev-pi/apply_waddle_secrets_remote.sh user@10.2.0.10 /path/to/.env
#   bash deploy/dev-pi/apply_waddle_secrets_remote.sh user@10.2.0.10 /path/to/.env /remote/path/waddle_view.sqlite
#
# Optional extra ssh/scp flags (quoted):
#   SSH_OPTS='-i ~/.ssh/id_pi' bash deploy/dev-pi/apply_waddle_secrets_remote.sh user@host
#
# Remote needs: bash 4+, waddlectl, secret-tool, and the SQLite DB already present.
set -euo pipefail

: "${SSH_OPTS:=}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REMOTE="${1:?usage: $0 <user@host> [.env path] [remote waddle_view.sqlite]}"
shift
ENV_LOCAL="${1:-$REPO_ROOT/apps/waddle_display/.env.development}"
shift || true
DB_REMOTE="${1:-}"
shift || true

APPLY_LOCAL="$SCRIPT_DIR/apply_waddle_secrets_from_env.sh"

if [[ ! -f "$ENV_LOCAL" ]]; then
  echo "error: local env file not found: $ENV_LOCAL" >&2
  exit 1
fi
if [[ ! -f "$APPLY_LOCAL" ]]; then
  echo "error: apply script not found: $APPLY_LOCAL" >&2
  exit 1
fi

RND="${RANDOM:-$$}"
TMP_E="waddle_apply.${RND}.env"
TMP_S="waddle_apply.${RND}.sh"

echo "scp env  -> $REMOTE:/tmp/$TMP_E"
scp $SSH_OPTS "$ENV_LOCAL" "$REMOTE:/tmp/$TMP_E"
echo "scp apply -> $REMOTE:/tmp/$TMP_S"
scp $SSH_OPTS "$APPLY_LOCAL" "$REMOTE:/tmp/$TMP_S"

REMOTE_CMD="bash /tmp/$TMP_S /tmp/$TMP_E"
if [[ -n "$DB_REMOTE" ]]; then
  REMOTE_CMD+=" $(printf '%q' "$DB_REMOTE")"
fi

echo "ssh $REMOTE $REMOTE_CMD"
set +e
# shellcheck disable=SC2086
ssh $SSH_OPTS "$REMOTE" "$REMOTE_CMD"
ec=$?
set -e
# shellcheck disable=SC2086
ssh $SSH_OPTS "$REMOTE" "rm -f /tmp/$TMP_E /tmp/$TMP_S" || true
[[ "$ec" -eq 0 ]] && echo 'Remote apply finished.'
exit "$ec"
