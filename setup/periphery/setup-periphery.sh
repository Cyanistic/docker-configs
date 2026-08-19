#!/usr/bin/env bash
# Once per managed machine.
# Installs Docker, Infisical CLI, and Komodo Periphery as a systemd service,
# then onboards it to Core.
#
# Usage:
#   sudo ./setup/periphery/setup-periphery.sh \
#     --core-address 'wss://komodo.cyanistic.com' \
#     --onboarding-key '<key>' \
#     --connect-as production
#
# --connect-as defaults to "production". Stacks in komodo/stacks target that name.
# Re-run is safe: the official periphery installer updates the binary and leaves
# existing config alone.

# shellcheck source=../lib/common.sh
. "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh"

CORE_ADDRESS=""
ONBOARDING_KEY=""
CONNECT_AS="production"
USER_MODE=0

usage() {
  cat <<'EOF'
usage: setup-periphery.sh --core-address ADDR --onboarding-key KEY [--connect-as NAME] [--user]

  --core-address     Core websocket, e.g. wss://komodo.cyanistic.com or ws://host:9120
  --onboarding-key   one-time key from the Komodo UI
  --connect-as       Server name inside Komodo (default: production)
  --user             install a systemd --user unit instead of a system unit
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --core-address) CORE_ADDRESS="${2:-}"; shift 2 ;;
    --onboarding-key) ONBOARDING_KEY="${2:-}"; shift 2 ;;
    --connect-as) CONNECT_AS="${2:-}"; shift 2 ;;
    --user) USER_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown arg: $1" ;;
  esac
done

[ -n "$CORE_ADDRESS" ] || die "--core-address is required"
[ -n "$ONBOARDING_KEY" ] || die "--onboarding-key is required"

if [ "$USER_MODE" -eq 0 ]; then
  require_root
fi

install_docker
install_infisical
install_secret_run
install_python3

if [ "$USER_MODE" -eq 0 ]; then
  log "installing Komodo Periphery (systemd system unit)"
  curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
    | python3 - \
      --core-address "$CORE_ADDRESS" \
      --onboarding-key "$ONBOARDING_KEY" \
      --connect-as "$CONNECT_AS"
  systemctl enable --now periphery
  systemctl --no-pager --full status periphery || true
else
  log "installing Komodo Periphery (systemd user unit)"
  curl -sSL https://raw.githubusercontent.com/moghtech/komodo/main/scripts/setup-periphery.py \
    | python3 - \
      --user \
      --core-address "$CORE_ADDRESS" \
      --onboarding-key "$ONBOARDING_KEY" \
      --connect-as "$CONNECT_AS"
  systemctl --user enable --now periphery
  systemctl --user --no-pager --full status periphery || true
  log "if this should stay up after logout: sudo loginctl enable-linger $USER"
fi

log ""
log "Periphery should now show as OK in Komodo under server '$CONNECT_AS'."
log "If Core should also manage this host and this IS the Core host, that is expected."
log "Next: execute the Resource Sync in Komodo so stacks land on '$CONNECT_AS'."
