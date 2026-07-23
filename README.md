# dotfiles

Portable zsh setup, replacing Oh My Zsh with a minimal, fast, managerless config.

Works on **macOS** and **Linux / WSL** (Ubuntu).

## One-liner install (fresh machine)

```bash
curl -sSL https://raw.githubusercontent.com/Gabriel-Cervo/dotfiles/main/bootstrap.sh | bash
```

This is idempotent — safe to re-run.

### Windows / WSL prerequisites

If you're on Windows, set up WSL first:

1. Open an **admin PowerShell** and run: `wsl --install`
2. Restart Windows when prompted
3. Launch **Ubuntu** from the Start menu; let it finish first-time setup
4. Inside the Ubuntu terminal, run the one-liner above

You'll also need a **Nerd Font** on the Windows side for the Starship prompt icons to render correctly. The easiest path:

- Open Windows Terminal
- Settings → Profiles → Defaults → Appearance → Font face → pick a Nerd Font (e.g., `CaskaydiaCove Nerd Font`, `JetBrainsMono Nerd Font`, `FiraCode Nerd Font`)
- Don't have one? Download from [nerdfonts.com](https://www.nerdfonts.com/), unzip, right-click the .ttf → "Install for all users"


## Sync (existing machine)

After editing the repo on one machine and pushing to GitHub:

```bash
bash ~/dotfiles/bootstrap.sh sync
```

This pulls the latest, re-applies symlinks, runs `brew bundle`, and updates the plugins.

## What it sets up

- zsh config split into `~/.config/zsh/`:
  - `env.zsh` — PATH, Homebrew shellenv, editor
  - `options.zsh` — (intentionally minimal; add your own)
  - `history.zsh` — shared history, 100k entries, dedup
  - `completions.zsh` — compinit + case/hyphen-insensitive + zsh-completions
  - `prompt.zsh` — Starship (one-line init)
  - `plugins.zsh` — autosuggestions + syntax-highlighting (managerless)
  - `tools/rbenv.zsh` — lazy-load wrapper
  - `tools/fnm.zsh` — lazy-load wrapper
- **[Starship](https://starship.rs/)** prompt (Rust-based, very fast)
- **zsh-autosuggestions** + **fast-syntax-highlighting** + **zsh-completions** (all sourced directly, no manager)
- **fnm** for Node, **rbenv** for Ruby — both lazy-loaded
- Shared history across sessions
- Case- and hyphen-insensitive completion

## Performance

Target: **< 200 ms** warm shell startup (down from ~640 ms with OMZ + Zinit + rbenv + nvm).

The lazy-load wrappers for `ruby`/`gem`/`bundle`/`irb`/`rake`/`rbenv` and `node`/`npm`/`npx`/`pnpm`/`yarn`/`fnm` defer the per-shell `init` cost until first invocation, so empty shells are very fast.

## Repo layout

```
dotfiles/
├── README.md
├── .gitignore
├── .gitattributes              # force LF for shell scripts
├── Brewfile                    # fnm, rbenv, starship
├── bootstrap.sh                # install / sync / uninstall
├── .node-version               # pinned Node version
├── .ruby-version               # pinned Ruby version
└── zsh/
    ├── zshrc                   # → ~/.zshrc (one-liner with escape hatch)
    ├── starship.toml           # → ~/.config/starship.toml (prompt config)
    └── config/
        ├── env.zsh
        ├── options.zsh
        ├── history.zsh
        ├── completions.zsh
        ├── prompt.zsh
        ├── plugins.zsh
        └── tools/
            ├── rbenv.zsh
            └── fnm.zsh
```

## Escape hatch — rolling back to Oh My Zsh

1. Open `~/.zshrc` in an editor (it will still be a symlink to `~/dotfiles/zsh/zshrc`)
2. Uncomment the two lines at the top:
   ```bash
   export ZSH="$HOME/.oh-my-zsh"
   source $ZSH/oh-my-zsh.sh
   ```
3. Comment out the `source "$HOME/.config/zsh/..."` lines
4. Reinstall OMZ (or extract from `~/dotfiles-omz-backup-*.tar.gz`)

The pre-migration backup is at `~/dotfiles-omz-backup-YYYYMMDD-HHMMSS.tar.gz`.

## Notes

- `fast-syntax-highlighting` is at `zdharma-continuum/fast-syntax-highlighting` (the `zsh-users` mirror is a 404 — long story; the canonical home moved).
- Supports macOS (via Homebrew) and Linux/WSL (via apt + official installer scripts).
- This is a **public** repo by design (so the `curl | bash` one-liner works without auth from any machine including a fresh company PC). If you want to keep some bits private, add them to a `local.zsh` and gitignore that file (currently not part of the layout).
- **Starship customization**: edit `~/dotfiles/zsh/starship.toml` and run `bash ~/dotfiles/bootstrap.sh sync` to push the change everywhere. See [starship.rs/config](https://starship.rs/config/) for the full schema.
