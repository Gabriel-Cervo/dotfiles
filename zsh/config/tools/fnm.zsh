# fnm.zsh — lazy-load wrapper for fnm
#
# Defers the `fnm env` cost (PATH setup, version resolution) until the first
# time you actually use node/npm/npx/pnpm/yarn/fnm. After the first call,
# the wrappers remove themselves and subsequent calls go directly to the
# real binaries on PATH.

_fnm_init() {
  # Remove the wrappers so future calls are direct
  unset -f node npm npx pnpm yarn fnm 2>/dev/null
  # Initialize fnm environment (adds Node binaries to PATH, sets up env vars)
  eval "$(fnm env --shell=zsh)"
  # Re-run the originally requested command
  local cmd="$1"
  shift
  command "$cmd" "$@"
}

node() { _fnm_init node "$@"; }
npm()  { _fnm_init npm  "$@"; }
npx()  { _fnm_init npx  "$@"; }
pnpm() { _fnm_init pnpm "$@"; }
yarn() { _fnm_init yarn "$@"; }
fnm()  { _fnm_init fnm  "$@"; }
