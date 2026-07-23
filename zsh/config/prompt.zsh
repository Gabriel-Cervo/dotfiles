# prompt.zsh — Starship prompt setup
#
# Starship is a fast, customizable cross-shell prompt written in Rust.
# The config lives at ~/.config/starship.toml (symlinked to ~/dotfiles/zsh/starship.toml).
# To customize, edit the file in the dotfiles repo and re-run:
#   bash ~/dotfiles/bootstrap.sh sync
# Or simply re-source this file in your current shell: source ~/.zshrc

# Initialize starship
eval "$(starship init zsh)"
