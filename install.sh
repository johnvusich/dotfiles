#!/usr/bin/env bash
# Dotfiles bootstrap for GitHub Codespaces (nf-core pipeline development)
# Usage:        ./install.sh
# Dry run:      DRY_RUN=1 ./install.sh
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
tmp_dir=""

cleanup() {
  if [[ -n "$tmp_dir" && -d "$tmp_dir" ]]; then
    rm -rf "$tmp_dir"
  fi
}

trap cleanup EXIT

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

# ── Sudo detection ────────────────────────────────────────────────────────────
# nf-core devcontainer runs as root, so sudo is unnecessary but harmless if present
if command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  SUDO=()
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
ensure_apt_pkg() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    log "$pkg already installed"
    return
  fi
  if [[ "${APT_UPDATED:-0}" != "1" ]]; then
    log "Updating apt package index"
    run "${SUDO[@]}" apt-get update -qq
    APT_UPDATED=1
  fi
  log "Installing apt package: $pkg"
  run "${SUDO[@]}" apt-get install -y -q "$pkg"
}

ensure_pipx_pkg() {
  local pkg="$1"
  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fxq "$pkg"; then
    log "pipx package already installed: $pkg"
  else
    log "Installing pipx package: $pkg"
    run pipx install "$pkg"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
log "Setting up GitHub Codespaces environment for nf-core development"

# ── Detect environment ────────────────────────────────────────────────────────
# The nf-core devcontainer (nfcore/devcontainer:latest) already ships with:
#   Nextflow, nf-core tools, nf-test, Apptainer, Java, Python, git
# This script is therefore additive — it skips anything already present.
IN_CODESPACE="${CODESPACES:-false}"
log "Running in Codespace: $IN_CODESPACE"

# ── Git identity ──────────────────────────────────────────────────────────────
# Codespaces auto-authenticates git but does NOT set user identity.
# Without this, commits will fail or use a wrong author.
log "Configuring git identity"
run git config --global user.name  "John Vusich"
run git config --global user.email "vusichj@gmail.com"

# Useful git defaults for nf-core PR workflow
run git config --global core.editor        "code --wait"   # VS Code as commit editor
run git config --global pull.rebase        false           # merge on pull, not rebase
run git config --global push.autoSetupRemote true          # no more --set-upstream errors
run git config --global init.defaultBranch main
run git config --global alias.lg          "log --oneline --graph --decorate --all"
run git config --global alias.st          "status"

# ── APT packages ──────────────────────────────────────────────────────────────
if command -v apt-get >/dev/null 2>&1; then
  # git and curl are already in the devcontainer; listed here for non-Codespace use
  ensure_apt_pkg git
  ensure_apt_pkg curl
  # Java: devcontainer ships with a JRE; only install if missing
  if ! command -v java >/dev/null 2>&1; then
    ensure_apt_pkg openjdk-17-jre-headless
  else
    log "Java already available: $(java -version 2>&1 | head -n1)"
  fi
  ensure_apt_pkg python3-pip
  ensure_apt_pkg pipx
else
  log "apt-get not found; skipping apt package installation"
fi

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# Persist PATH addition across sessions
BASHRC="$HOME/.bashrc"
if ! grep -q '\.local/bin' "$BASHRC" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
fi

if ! command -v pipx >/dev/null 2>&1; then
  log "pipx is required but was not found in PATH after install"
  exit 1
fi
run pipx ensurepath

# ── nf-core tools ─────────────────────────────────────────────────────────────
# The devcontainer ships with nf-core tools, but the version may lag behind.
# We install via pipx so we can pin or upgrade independently of the image.
# NOTE: nf-core/circdna dev branch currently uses template version 3.3.1;
#       set NF_CORE_VERSION to match the template you are syncing to.
NF_CORE_VERSION="${NF_CORE_VERSION:-3.5.2}"
if pipx list --short 2>/dev/null | awk '{print $1}' | grep -Fxq "nf-core"; then
  INSTALLED_VERSION=$(pipx list --short 2>/dev/null | grep "^nf-core" | awk '{print $2}')
  if [[ "$INSTALLED_VERSION" == "$NF_CORE_VERSION" ]]; then
    log "nf-core $NF_CORE_VERSION already installed via pipx"
  else
    log "Upgrading nf-core from $INSTALLED_VERSION to $NF_CORE_VERSION"
    run pipx install "nf-core==$NF_CORE_VERSION" --force
  fi
else
  log "Installing nf-core $NF_CORE_VERSION via pipx"
  run pipx install "nf-core==$NF_CORE_VERSION"
fi

# ── pre-commit ────────────────────────────────────────────────────────────────
ensure_pipx_pkg pre-commit

# ── Nextflow ──────────────────────────────────────────────────────────────────
# The devcontainer ships with Nextflow. Only install if genuinely missing
# (e.g., running this script outside a Codespace on a plain Linux machine).
if command -v nextflow >/dev/null 2>&1; then
  log "Nextflow already installed: $(nextflow -version 2>&1 | grep version | head -n1 | xargs)"
else
  log "Nextflow not found — installing via get.nextflow.io"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY_RUN: would download and install Nextflow to $HOME/.local/bin"
  else
    tmp_dir="$(mktemp -d)"
    (
      cd "$tmp_dir"
      curl -fsSL https://get.nextflow.io | bash
      mkdir -p "$HOME/.local/bin"
      mv nextflow "$HOME/.local/bin/nextflow"
      chmod +x "$HOME/.local/bin/nextflow"
    )
  fi
fi

# ── Shell aliases ─────────────────────────────────────────────────────────────
# Only append once (idempotent guard)
if ! grep -q "# nf-core dotfiles aliases" "$BASHRC" 2>/dev/null; then
  log "Adding shell aliases to $BASHRC"
  cat >> "$BASHRC" << 'EOF'

# nf-core dotfiles aliases
alias ll='ls -lah --color=auto'
alias gs='git status'
alias glog='git log --oneline --graph --decorate --all'

# nf-core shortcuts
alias nfl='nf-core pipelines lint'
alias nfs='nf-core pipelines sync'

# Run the pipeline test profile — always use singularity in Codespaces
# (docker profile does not work inside the devcontainer)
alias nftest='nextflow run . -profile test,singularity --outdir ./results'

# Quickly check which template version the current pipeline is on
alias nfver='grep nf_core_version .nf-core.yml 2>/dev/null || echo "No .nf-core.yml found"'
EOF
fi

# ── Version summary ───────────────────────────────────────────────────────────
log "--- Installed tool versions ---"
if [[ "$DRY_RUN" == "1" ]]; then
  log "DRY_RUN: skipping version checks"
else
  command -v java      >/dev/null && java -version 2>&1 | head -n1       || log "java not found"
  command -v nextflow  >/dev/null && nextflow -version 2>&1 | grep version | head -n1 | xargs || log "nextflow not found"
  command -v nf-core   >/dev/null && nf-core --version                   || log "nf-core not found"
  command -v pre-commit>/dev/null && pre-commit --version                 || log "pre-commit not found"
  command -v git       >/dev/null && git --version                        || log "git not found"
fi

log "Setup complete. Run 'source ~/.bashrc' or open a new terminal to load aliases."
