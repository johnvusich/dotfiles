#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

log() {
  echo "[install] $*"
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: $*"
  else
    "$@"
  fi
}

if command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  SUDO=()
fi

ensure_apt_pkg() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    log "$pkg already installed"
    return
  fi

  if [[ "${APT_UPDATED:-0}" != "1" ]]; then
    log "Updating apt package index"
    run "${SUDO[@]}" apt-get update
    APT_UPDATED=1
  fi

  log "Installing apt package: $pkg"
  run "${SUDO[@]}" apt-get install -y "$pkg"
}

ensure_pipx_pkg() {
  local pkg="$1"
  if pipx list --short 2>/dev/null | grep -qx "$pkg"; then
    log "Upgrading pipx package: $pkg"
    run pipx upgrade "$pkg"
  else
    log "Installing pipx package: $pkg"
    run pipx install "$pkg"
  fi
}

log "Setting up GitHub Codespaces environment for nf-core development"

if command -v apt-get >/dev/null 2>&1; then
  ensure_apt_pkg git
  ensure_apt_pkg curl
  ensure_apt_pkg openjdk-17-jre-headless
  ensure_apt_pkg python3-pip
  ensure_apt_pkg pipx
else
  log "apt-get not found; skipping apt package installation"
fi

export PATH="$HOME/.local/bin:$PATH"
run pipx ensurepath

ensure_pipx_pkg nf-core
ensure_pipx_pkg pre-commit

if command -v nextflow >/dev/null 2>&1; then
  log "Nextflow already installed"
else
  log "Installing Nextflow"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: curl -fsSL https://get.nextflow.io | bash"
    log "DRY_RUN: mkdir -p $HOME/.local/bin"
    log "DRY_RUN: mv nextflow $HOME/.local/bin/nextflow"
    log "DRY_RUN: chmod +x $HOME/.local/bin/nextflow"
  else
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    (
      cd "$tmp_dir"
      curl -fsSL https://get.nextflow.io | bash
      mkdir -p "$HOME/.local/bin"
      mv nextflow "$HOME/.local/bin/nextflow"
      chmod +x "$HOME/.local/bin/nextflow"
    )
  fi
fi

log "Installed tool versions"
run bash -lc 'java -version 2>&1 | head -n 1'
run nf-core --version
run pre-commit --version
run nextflow -version

log "Setup complete"
