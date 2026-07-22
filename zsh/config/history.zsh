# history.zsh — history configuration

HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"

# Share history across all open sessions in real time
setopt SHARE_HISTORY

# Append to HISTFILE immediately, not at shell exit
setopt INC_APPEND_HISTORY

# Quality-of-life options
setopt HIST_IGNORE_DUPS       # don't record consecutive duplicates
setopt HIST_IGNORE_SPACE      # don't record commands starting with a space
setopt HIST_VERIFY            # confirm before running !!-style expansions
