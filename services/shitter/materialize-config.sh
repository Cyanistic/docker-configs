#!/usr/bin/env bash
# Render deploy-time secrets from Infisical, then exec compose.
# Invoked via the stack wrapper on `up` only:
#   secret-run -- ./materialize-config.sh [[COMPOSE_COMMAND]]
# secret-run exposes the /shitter folder (env prod) as env vars.
# Nitter itself reads only files (NITTER_CONF_FILE / NITTER_SESSIONS_FILE
# are paths, not values), so we materialize both gitignored files here:
#   nitter.conf.template + $HMAC_KEY -> ./nitter.conf
#   $SESSIONS_JSONL                -> ./sessions.jsonl

set -euo pipefail

[ -n "${HMAC_KEY:-}" ] || {
  echo "materialize-config: HMAC_KEY is empty (Infisical folder /shitter, env prod)" >&2
  exit 1
}
[ -n "${SESSIONS_JSONL:-}" ] || {
  echo "materialize-config: SESSIONS_JSONL is empty (Infisical folder /shitter, env prod)" >&2
  exit 1
}
[ -f ./nitter.conf.template ] || {
  echo "materialize-config: nitter.conf.template missing in run directory" >&2
  exit 1
}
if printf '%s' "$SESSIONS_JSONL" | grep -q "PASTE_ME"; then
  echo "materialize-config: SESSIONS_JSONL still has PASTE_ME placeholders" >&2
  exit 1
fi

# HMAC_KEY is hex (openssl rand -hex 32): no sed-special characters.
sed "s/@@HMAC_KEY@@/${HMAC_KEY}/g" ./nitter.conf.template > ./nitter.conf
if grep -q "@@HMAC_KEY@@" ./nitter.conf; then
  echo "materialize-config: placeholder survived rendering (template changed?)" >&2
  exit 1
fi

# Normalize sessions to exactly one trailing newline (one JSON object per line).
rendered=$(printf '%s' "$SESSIONS_JSONL")
printf '%s\n' "$rendered" > ./sessions.jsonl
chmod 644 ./nitter.conf ./sessions.jsonl # container reads as uid 998
exec "$@"
