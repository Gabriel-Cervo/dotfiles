# rbenv.zsh — lazy-load wrapper for rbenv
#
# Defers the ~80ms `rbenv init` cost until the first time you actually use
# ruby/gem/bundle/irb/rake/rbenv. After that first call, the wrappers
# remove themselves and subsequent calls go straight to the real binaries.

_rbenv_init() {
  # Remove the wrappers so future calls are direct
  unset -f ruby gem bundle irb rake rbenv 2>/dev/null
  # Initialize rbenv (adds shims to PATH, registers completions, etc.)
  eval "$(rbenv init - zsh)"
  # Re-run the originally requested command via the now-initialized environment
  local cmd="$1"
  shift
  command "$cmd" "$@"
}

ruby()  { _rbenv_init ruby  "$@"; }
gem()   { _rbenv_init gem   "$@"; }
bundle(){ _rbenv_init bundle "$@"; }
irb()   { _rbenv_init irb   "$@"; }
rake()  { _rbenv_init rake  "$@"; }
rbenv() { _rbenv_init rbenv "$@"; }
