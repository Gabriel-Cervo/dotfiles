# env.zsh — environment variables and PATH

# User-local bin
export PATH="$HOME/.local/bin:$PATH"

# Homebrew shellenv (Apple Silicon default; Intel users get this from /usr/local)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Locale (uncomment if you hit encoding issues)
# export LANG=en_US.UTF-8

# Editor — uncomment and set your preference
# export EDITOR='code'
# export VISUAL="$EDITOR"

# Dart CLI completion (preserved from previous config; no-op if absent)
[[ -f "$HOME/.dart-cli-completion/zsh-config.zsh" ]] && \
  . "$HOME/.dart-cli-completion/zsh-config.zsh"
