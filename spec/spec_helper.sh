# shellcheck shell=sh
# Loaded by ShellSpec (running under zsh). Plugin code is zsh-only, so it is
# loaded from inside a function that switches to zsh emulation.

load_plugin() {
  emulate -L zsh
  zmodload zsh/datetime
  zmodload -F zsh/system p:sysparams 2> /dev/null
  zmodload -F zsh/stat b:zstat
  source "${SHELLSPEC_PROJECT_ROOT}/lib/command.zsh"
  source "${SHELLSPEC_PROJECT_ROOT}/lib/git.zsh"
  source "${SHELLSPEC_PROJECT_ROOT}/lib/keymap.zsh"
  source "${SHELLSPEC_PROJECT_ROOT}/lib/transient.zsh"
}

spec_helper_precheck() {
  load_plugin
}

# Stand-in for the zle builtin, which only works inside the line editor.
# Records every call in ZLE_CALLS and fails like `zle` does outside ZLE.
stub_zle() {
  ZLE_CALLS=''
  zle() {
    ZLE_CALLS="${ZLE_CALLS}${*};"
    case "$1" in -F) return 0 ;; esac
    return 1
  }
}
