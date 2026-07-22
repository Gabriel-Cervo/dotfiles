#!/usr/bin/env bash
# bootstrap.sh — install / sync / uninstall for the dotfiles repo
#
# Usage:
#   bash bootstrap.sh            # install (default) — full first-time setup
#   bash bootstrap.sh sync       # light sync: git pull, brew bundle, plugin updates
#   bash bootstrap.sh uninstall  # remove symlinks (does not restore from backup)
#   bash bootstrap.sh help       # show this help
#
# Designed to be run via:
#   curl -sSL https://raw.githubusercontent.com/Gabriel-Cervo/dotfiles/main/bootstrap.sh | bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
OS="$(uname -s)"

# ---------- output helpers ----------

log()  { printf "\033[1;34m[bootstrap]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[bootstrap]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2; }

# ---------- helpers ----------

ensure_brew() {
  if [[ "$OS" != "Darwin" ]]; then
    warn "Non-macOS detected ($OS); skipping Homebrew."
    return 1
  fi
  if command -v brew &>/dev/null; then
    return 0
  fi
  log "Installing Homebrew (may prompt for sudo)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

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

  # If something else exists at target, back it up (unless it's already in the dotfiles repo)
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
  log "Starting install..."

  # (a) Homebrew
  ensure_brew || warn "Homebrew unavailable; brew-related steps will be skipped."

  # (b) Brew bundle
  if command -v brew &>/dev/null && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    log "Running brew bundle..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
  fi

  # (c) p10k
  mkdir -p "$HOME/.zsh/themes"
  clone_or_pull https://github.com/romkatv/powerlevel10k.git "$HOME/.zsh/themes/powerlevel10k"

  # (d) Plugins (note: fast-syntax-highlighting lives in zdharma-continuum, not zsh-users)
  mkdir -p "$HOME/.zsh/plugins"
  clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$HOME/.zsh/plugins/zsh-autosuggestions"
  clone_or_pull https://github.com/zdharma-continuum/fast-syntax-highlighting "$HOME/.zsh/plugins/fast-syntax-highlighting"
  clone_or_pull https://github.com/zsh-users/zsh-completions        "$HOME/.zsh/plugins/zsh-completions"

  # (e) Symlinks
  log "Creating symlinks..."
  ensure_symlink "$HOME/.zshrc"          "$DOTFILES_DIR/zsh/zshrc"
  ensure_symlink "$HOME/.config/zsh"     "$DOTFILES_DIR/zsh/config"
  ensure_symlink "$HOME/.p10k.zsh"       "$DOTFILES_DIR/zsh/p10k.zsh"

  # (f) Node version
  if command -v fnm &>/dev/null; then
    local node_ver
    if node_ver="$(read_pinned "$DOTFILES_DIR/.node-version")"; then
      log "Installing Node $node_ver via fnm..."
      fnm install "$node_ver" || warn "  fnm install $node_ver failed (continuing)"
      fnm default "$node_ver" 2>/dev/null || true
    fi
  else
    warn "fnm not on PATH; skipping Node version install."
  fi

  # (g) Ruby version
  if command -v rbenv &>/dev/null; then
    local ruby_ver
    if ruby_ver="$(read_pinned "$DOTFILES_DIR/.ruby-version")"; then
      log "Installing Ruby $ruby_ver via rbenv..."
      rbenv install "$ruby_ver" -s 2>/dev/null || warn "  rbenv install $ruby_ver failed (continuing; you may need build deps)"
    fi
  else
    warn "rbenv not on PATH; skipping Ruby version install."
  fi

  # (h) p10k wizard on first run
  if [[ ! -s "$HOME/.p10k.zsh" ]]; then
    if [[ -t 0 && -t 1 ]]; then
      log "First run: launching p10k configure..."
      log "  (If you want to skip this and run it manually later, press Ctrl-C now.)"
      sleep 2
      ( cd "$HOME" && ZSH="$HOME/.zsh/themes/powerlevel10k" command p10k configure ) || \
        warn "  p10k configure did not complete; you can re-run it manually."
    else
      warn "Non-interactive shell; skipping p10k configure. Run it manually after install:"
      warn "  p10k configure"
    fi
  else
    log "p10k config already present at ~/.p10k.zsh; skipping wizard."
  fi

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
  ensure_symlink "$HOME/.zshrc"      "$DOTFILES_DIR/zsh/zshrc"
  ensure_symlink "$HOME/.config/zsh" "$DOTFILES_DIR/zsh/config"
  ensure_symlink "$HOME/.p10k.zsh"   "$DOTFILES_DIR/zsh/p10k.zsh"

  # brew bundle
  if command -v brew &>/dev/null && [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
    log "Running brew bundle..."
    brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "brew bundle reported errors (continuing)"
  fi

  # Update plugins
  clone_or_pull https://github.com/romkatv/powerlevel10k.git         "$HOME/.zsh/themes/powerlevel10k"
  clone_or_pull https://github.com/zsh-users/zsh-autosuggestions     "$HOME/.zsh/plugins/zsh-autosuggestions"
  clone_or_pull https://github.com/zdharma-continuum/fast-syntax-highlighting "$HOME/.zsh/plugins/fast-syntax-highlighting"
  clone_or_pull https://github.com/zsh-users/zsh-completions        "$HOME/.zsh/plugins/zsh-completions"

  log "Sync complete."
}

cmd_uninstall() {
  warn "Removing dotfiles symlinks..."
  for link in "$HOME/.zshrc" "$HOME/.config/zsh" "$HOME/.p10k.zsh"; do
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
  bash bootstrap.sh sync       # light sync: git pull, brew bundle, plugin updates
  bash bootstrap.sh uninstall  # remove symlinks (does not restore from backup)
  bash bootstrap.sh help       # show this help

On a fresh macOS machine, you can install everything in one command:
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
