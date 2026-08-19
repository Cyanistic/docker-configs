#!/usr/bin/env bash
# Once per Komodo installation.
# Installs Docker, Infisical CLI, and secret-run, then starts Komodo Core
# against MongoDB Atlas. Does not install Periphery and does not deploy app stacks.

# shellcheck source=../lib/common.sh
. "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh"

require_root
ROOT="$(repo_root)"
CORE_DIR="$ROOT/services/komodo-core"
AUTH_FILE=/etc/secret-run/infisical.env

install_docker
install_infisical
install_secret_run

if [ ! -f "$CORE_DIR/compose.env" ]; then
  cp "$CORE_DIR/compose.env.example" "$CORE_DIR/compose.env"
  log "wrote $CORE_DIR/compose.env from the example"
  log "edit it before this is a real install: KOMODO_HOST, title, feature flags"
fi

if ! grep -Eq '^(INFISICAL_TOKEN|INFISICAL_CLIENT_ID)=' "$AUTH_FILE" 2>/dev/null; then
  die "fill $AUTH_FILE with a machine identity or token, then re-run.
In Infisical, put KOMODO_DATABASE_URI under /komodo-core (prod):
  mongodb+srv://user:pass@cluster.mongodb.net/komodo?retryWrites=true&w=majority
Allow this machine's IP in Atlas Network Access."
fi

log "starting Komodo Core via secret-run"
(
  cd "$CORE_DIR"
  secret-run -- \
    docker compose --env-file "$CORE_DIR/compose.env" -f "$CORE_DIR/docker-compose.yml" up -d
)

log ""
log "Core is up on port 9120, talking to Atlas via KOMODO_DATABASE_URI."
log "Next:"
log "  1. open http://<this-host>:9120 (or whatever KOMODO_HOST is)"
log "  2. log in, change the admin password"
log "  3. create an onboarding key"
log "  4. run setup/periphery/setup-periphery.sh on each machine you want managed"
log "  5. in Komodo, create a Resource Sync pointing at this repo / main / path komodo"
