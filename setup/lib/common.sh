# Shared helpers for setup-core.sh and setup-periphery.sh.
# Sourced, not executed.

set -euo pipefail

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "run as root (sudo $0 ...)"
  fi
}

repo_root() {
  # setup/<core|periphery>/this-script -> repo root
  cd "$(dirname "$0")/../.." && pwd
}

have() { command -v "$1" >/dev/null 2>&1; }

detect_os() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}"
  else
    printf 'unknown\n'
  fi
}

install_docker() {
  if have docker && docker compose version >/dev/null 2>&1; then
    log "docker already installed: $(docker --version)"
    return 0
  fi
  log "installing Docker Engine + Compose plugin"
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  have docker || die "docker install finished but docker is not on PATH"
  docker compose version >/dev/null || die "docker compose plugin missing after install"
}

install_python3() {
  if have python3; then
    return 0
  fi
  case "$(detect_os)" in
    debian|ubuntu)
      apt-get update -y
      apt-get install -y python3
      ;;
    rhel|centos|rocky|almalinux|fedora)
      if have dnf; then dnf install -y python3; else yum install -y python3; fi
      ;;
    *)
      die "python3 is required (periphery installer) and I don't know how to install it on this OS"
      ;;
  esac
}

install_secret_run() {
  local src_dir dest_bin dest_dir dest_cfg dest_auth
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ "$(id -u)" -eq 0 ]; then
    dest_bin=/usr/local/bin/secret-run
    dest_dir=/etc/secret-run
  else
    dest_bin="${HOME}/.local/bin/secret-run"
    dest_dir="${XDG_CONFIG_HOME:-$HOME/.config}/secret-run"
    mkdir -p "$(dirname "$dest_bin")"
  fi

  mkdir -p "$dest_dir"
  dest_cfg="$dest_dir/config"
  dest_auth="$dest_dir/infisical.env"

  install -m 0755 "$src_dir/secret-run" "$dest_bin"
  if [ ! -f "$dest_cfg" ]; then
    install -m 0644 "$src_dir/secret-run.conf.example" "$dest_cfg"
    log "wrote $dest_cfg (backend = infisical)"
  fi
  if [ ! -f "$dest_auth" ]; then
    install -m 0600 "$src_dir/infisical.env.example" "$dest_auth"
    log "wrote $dest_auth — fill in machine identity / token before first run"
  fi
  log "secret-run installed at $dest_bin"
}

install_infisical() {
  if have infisical; then
    log "infisical already installed: $(infisical --version 2>/dev/null || true)"
    return 0
  fi
  log "installing Infisical CLI"
  case "$(detect_os)" in
    debian|ubuntu)
      curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash
      apt-get install -y infisical
      ;;
    rhel|centos|rocky|almalinux|fedora)
      curl -1sLf 'https://artifacts-cli.infisical.com/setup.rpm.sh' | bash
      if have dnf; then dnf install -y infisical; else yum install -y infisical; fi
      ;;
    *)
      die "don't know how to install Infisical CLI on this OS; see https://infisical.com/docs/cli/overview"
      ;;
  esac
  have infisical || die "infisical install finished but infisical is not on PATH"
}
