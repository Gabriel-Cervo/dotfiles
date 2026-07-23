#!/usr/bin/env bash
# bootstrap.sh — install / sync / uninstall for the dotfiles repo
#
# Usage:
#   bash bootstrap.sh            # install (default) — full first-time setup
#   bash bootstrap.sh sync       # light sync: git pull, brew/apt, plugin updates
#   bash bootstrap.sh uninstall  # remove symlinks (does not restore from backup)
#   bash bootstrap.sh help       # show this help
#
# Designed to be run via:
#   curl -sSL https://raw.githubusercontent.com/Gabriel-Cervo/dotfiles/main/bootstrap.sh | bash
#
# Supports:
#   - macOS (via Homebrew)
#   - Linux / WSL (via apt; rbenv via git clone; fnm via official installer)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# OS detection
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="mac" ;;
  Linux)  PLATFORM="linux" ;;
  *)
    err "Unsupported OS: $OS"
    err "This script supports macOS and Linux/WSL only."
    exit 1
    ;;
esac

# ---------- output helpers ----------

log()  { printf "\033[1;34m[bootstrap]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[bootstrap]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2; }

# ---------- package-manager helpers ----------

ensure_brew() {
  if [[ "$PLATFORM" != "mac" ]]; then return 0; fi
  if command -v brew &>/dev/null; then return 0; fi
  log "Installing Homebrew (may prompt for sudo)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_apt() {
  if [[ "$PLATFORM" != "linux" ]]; then return 0; fi
  if command -v apt-get &>/dev/null; then
    log "apt-get available."
    return 0
  fi
  err "This Linux distribution doesn't have apt-get."
  err "Please install these packages manually, then re-run:"
  err "  zsh, git, curl, build-essential, libssl-dev, libreadline-dev, zlib1g-dev"
  exit 1
}

ensure_linux_packages() {
  if [[ "$PLATFORM" != "linux" ]]; then return 0; fi

  local pkgs=(zsh git curl ca-certificates)
  local build_pkgs=(build-essential libssl-dev libreadline-dev zlib1g-dev)

  log "Ensuring base packages (zsh, git, curl)..."
  if ! sudo -n true 2>/dev/null; then
    warn "  sudo will prompt for your password."
  fi
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends "${pkgs[@]}"

  log "Ensuring Ruby build dependencies..."
  sudo apt-get install -y --no-install-recommends "${build_pkgs[@]}"
}

# ---------- tool install helpers ----------

ensure_fnm() {
  if command -v fnm &>/dev/null; then
    log "fnm already installed."
    return 0
  fi
  case "$PLATFORM" in
    mac)
      log "Installing fnm via Homebrew..."
      brew install fnm
      ;;
    linux)
      log "Installing fnm via official installer (no shell-config changes)..."
      curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
      # Make fnm available in this session (env.zsh handles future shells)
      export PATH="$HOME/.local/bin:$PATH"
      ;;
  esac
}

ensure_rbenv() {
  if command -v rbenv &>/dev/null; then
    log "rbenv already installed."
    return 0
  fi
  case "$PLATFORM" in
    mac)
      log "Installing rbenv via Homebrew..."
      brew install rbenv
      ;;
    linux)
      log "Installing rbenv to ~/.rbenv (single-user) + ruby-build plugin..."
      git clone https://github.com/rbenv/rbenv.git            "$HOME/.rbenv"
      git clone https://github.com/rbenv/ruby-build.git      "$HOME/.rbenv/plugins/ruby-build"
      # Add to PATH for this session
      export PATH="$HOME/.rbenv/bin:$PATH"
      eval "$(rbenv init - zsh)"
      ;;
  esac
}

chsh_to_zsh() {
  if [[ "$PLATFORM" != "linux" ]]; then return 0; fi
  if [[ "$SHELL" == *"zsh"* ]]; then
    log "Default shell is already zsh; skipping chsh."
    return 0
  fi
  if ! command -v zsh &>/dev/null; then
    warn "zsh not found; skipping chsh. Install zsh and run: chsh -s \$(which zsh)"
    return 0
  fi
  log "Changing default shell to zsh (may prompt for password)..."
  chsh -s "$(command -v zsh)" "$USER" || warn "  chsh failed; you can do it manually later."
}

ensure_starship() {
  if command -v starship &>/dev/null; then
    log "starship already installed."
    return 0
  fi
  case "$PLATFORM" in
    mac)
      log "Installing starship via Homebrew..."
      brew install starship
      ;;
    linux)
      log "Installing starship via official installer (to ~/.local/bin, no sudo)..."
      curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin"
      export PATH="$HOME/.local/bin:$PATH"
      ;;
  esac
}

# ---------- generic helpers ----------

clone_or_pull() {
  local url="$1"
  local dest="$2"
  if [[ -d "$dest/.git" ]]; then
    log "Updating $(basename "$dest")..."
    GIT_TERMINAL_PROMPT=0 git -C "$dest" pull --ff-only 2>/dev/null \
      || warn "  could not fast-forward $(basename "$dest"); leaving as-is"
  else
    log "Cloning $(basename "$dest")..."
    rm -rf "$dest"
    GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$dest"
  fi
}

ensure_symlink() {
  local target="$1"
  local source="$2"

  # Already correct
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
    return 0
  fi

  # If something else exists at target, back it up
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ "$(readlink "$target" 2>/dev/null)" != "$source" ]]; then
      mkdir -p "$BACKUP_DIR"
      warn "Backing up $target → $BACKUP_DIR/"
      mv "$target" "$BACKUP_DIR/$(basename "$target")"
    fi
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  log "Linked: $target → $source"
}

read_pinned() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  tr -d '[:space:]' < "$file"
}

# ---------- subcommands ----------

cmd_install() {
  log "Starting install on $PLATFORM ($OS)..."

  # If we're being run from a non-dotfiles location (e.g. piped from curl),
  # clone the real repo to ~/dotfiles/ and re-exec from there.
  if [[ ! -f "$DOTFILES_DIR/Brewfile" ]] || [[ ! -d "$DOTFILES_DIR/zsh" ]]; then
    local target="$HOME/dotfiles"
    if [[ -d "$target" ]] && [[ -f "$target/Brewfile" ]] && [[ -d "$target/zsh" ]]; then
      log "Existing dotfiles repo at $target; re-running from there."
    else
      log "Cloning Gabriel-Cervo/dotfiles to $target..."
      mkdir -p "$(dirname "$target")"
      if [[ -d "$target/.git" ]]; then
        git -C "$target" pull --ff-only 2>/dev/null \
          || err "Could not update $target; resolve manually and re-run."
      else
        [[ -z "$(ls -A "$target" 2>/dev/null)" ]] || err "$target exists and is not empty; refusing to clone into it."
        GIT_TERMINAL_PROMPT=0 git clone --depth=1 https://github.com/Gabriel-Cervo/dotfiles.git "$target"
      fi
    fi
    log "Re-executing from $target/bootstrap.sh..."
    exec bash "$target/bootstrap.sh" install
  fi

  # (a) Package manager
  ensure_brew || true
  ensure_apt

  # (b) Linux packages + build deps (no-op on macOS)
  ensure_linux_packages

  # (c) Brew bundle (macOS only)
  if [[ "$PLATFORM" == "mac" ]] && command -v brew &>/dev/null && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    log "Running brew bundle..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
  fi

  # (d) fnm
  ensure_fnm

  # (e) rbenv
  ensure_rbenv

  # (f) starship
  ensure_starship

  # (g) Plugins (note: fast-syntax-highlighting lives in zdharma-continuum, not zsh-users)
  mkdir -p "$HOME/.zsh/plugins"
  clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$HOME/.zsh/plugins/zsh-autosuggestions"
  clone_or_pull https://github.com/zdharma-continuum/fast-syntax-highlighting "$HOME/.zsh/plugins/fast-syntax-highlighting"
  clone_or_pull https://github.com/zsh-users/zsh-completions        "$HOME/.zsh/plugins/zsh-completions"

  # (h) Symlinks
  log "Creating symlinks..."
  ensure_symlink "$HOME/.zshrc"               "$DOTFILES_DIR/zsh/zshrc"
  ensure_symlink "$HOME/.config/zsh"          "$DOTFILES_DIR/zsh/config"
  ensure_symlink "$HOME/.config/starship.toml" "$DOTFILES_DIR/zsh/starship.toml"

  # (i) Node version
  if command -v fnm &>/dev/null; then
    local node_ver
    if node_ver="$(read_pinned "$DOTFILES_DIR/.node-version")" && [[ -n "$node_ver" ]]; then
      log "Installing Node $node_ver via fnm..."
      fnm install "$node_ver" || warn "  fnm install $node_ver failed (continuing)"
      fnm default "$node_ver" 2>/dev/null || true
    fi
  else
    warn "fnm not on PATH; skipping Node version install."
  fi

  # (j) Ruby version
  if command -v rbenv &>/dev/null; then
    local ruby_ver
    if ruby_ver="$(read_pinned "$DOTFILES_DIR/.ruby-version")" && [[ -n "$ruby_ver" ]]; then
      log "Installing Ruby $ruby_ver via rbenv..."
      # On Linux, rbenv was just cloned and may not be on PATH yet
      if [[ "$PLATFORM" == "linux" ]] && [[ -d "$HOME/.rbenv" ]] && ! command -v rbenv &>/dev/null; then
        export PATH="$HOME/.rbenv/bin:$PATH"
        eval "$(rbenv init - zsh)"
      fi
      rbenv install "$ruby_ver" -s 2>/dev/null || warn "  rbenv install $ruby_ver failed (continuing; you may need build deps)"
    fi
  else
    warn "rbenv not on PATH; skipping Ruby version install."
  fi

  # (k) chsh to zsh (Linux only; no-op on macOS where zsh is default)
  chsh_to_zsh

  # (l) Starship is ready. Config is in the repo (~/dotfiles/zsh/starship.toml).
  log "Starship prompt ready (config symlinked from repo)."
  log "  To customize, edit ~/dotfiles/zsh/starship.toml and run: bash ~/dotfiles/bootstrap.sh sync"

  log "Install complete."
  log "  Open a new shell, or: source ~/.zshrc"
}

cmd_sync() {
  log "Syncing dotfiles..."

  # Pull latest
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "Pulling latest from origin..."
    git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null \
      || warn "  git pull had errors (continuing)"
  else
    warn "Not a git repo at $DOTFILES_DIR; skipping pull."
  fi

  # Re-apply symlinks
  ensure_symlink "$HOME/.zshrc"                "$DOTFILES_DIR/zsh/zshrc"
  ensure_symlink "$HOME/.config/zsh"           "$DOTFILES_DIR/zsh/config"
  ensure_symlink "$HOME/.config/starship.toml" "$DOTFILES_DIR/zsh/starship.toml"

  # Package manager + tool sanity
  ensure_brew || true
  ensure_apt
  if [[ "$PLATFORM" == "mac" ]] && command -v brew &>/dev/null && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    log "Running brew bundle..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
  fi
  ensure_fnm
  ensure_rbenv
  ensure_starship

  # Update plugins
  clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$HOME/.zsh/plugins/zsh-autosuggestions"
  clone_or_pull https://github.com/zdharma-continuum/fast-syntax-highlighting "$HOME/.zsh/plugins/fast-syntax-highlighting"
  clone_or_pull https://github.com/zsh-users/zsh-completions        "$HOME/.zsh/plugins/zsh-completions"

  log "Sync complete."
}

cmd_uninstall() {
  warn "Removing dotfiles symlinks..."
  for link in "$HOME/.zshrc" "$HOME/.config/zsh" "$HOME/.config/starship.toml"; do
    if [[ -L "$link" ]]; then
      log "  removing $link"
      rm "$link"
    else
      warn "  $link is not a symlink; leaving as-is"
    fi
  done
  log "Done. To fully restore the old OMZ setup, untar your backup:"
  log "  ls -1 ~ | grep dotfiles-omz-backup"
}

cmd_help() {
  cat <<EOF
bootstrap.sh — dotfiles setup

Usage:
  bash bootstrap.sh            # install (default) — full first-time setup
  bash bootstrap.sh sync       # light sync: git pull, brew/apt, plugin updates
  bash bootstrap.sh uninstall  # remove symlinks (does not restore from backup)
  bash bootstrap.sh help       # show this help

Supports:
  - macOS (via Homebrew)
  - Linux / WSL (via apt; rbenv via git clone; fnm via official installer)

On a fresh machine, you can install everything in one command:
  macOS / Linux / WSL:
    curl -sSL https://raw.githubusercontent.com/Gabriel-Cervo/dotfiles/main/bootstrap.sh | bash
EOF
}

# ---------- entry ----------

case "${1:-install}" in
  install)        cmd_install ;;
  sync)           cmd_sync ;;
  uninstall)      cmd_uninstall ;;
  -h|--help|help) cmd_help ;;
  *)
    err "Unknown command: $1"
    cmd_help
    exit 1
    ;;
esac
