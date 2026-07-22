# completions.zsh — zsh completion system

# Add zsh-completions to fpath BEFORE compinit
fpath=("$HOME/.zsh/plugins/zsh-completions/src" $fpath)

# Load the completion system
# `-u` skips the insecure-directories security check (small speedup, fine for personal use)
autoload -Uz compinit
compinit -u

# Case- and hyphen-insensitive completion (the OMZ defaults)
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'
