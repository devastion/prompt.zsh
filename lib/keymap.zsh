typeset -g PROMPT_VICMD_SYMBOL="${PROMPT_VICMD_SYMBOL:-"❮"}"

# Shows PROMPT_VICMD_SYMBOL in place of PROMPT_SYMBOL while the vi command
# keymap is active. The insert keymap, and emacs mode, keep PROMPT_SYMBOL.
_prompt_keymap_select() {
  emulate -L zsh

  local symbol=''
  case "${KEYMAP}" in
    vicmd | visual | viopp) symbol="${PROMPT_VICMD_SYMBOL}" ;;
  esac

  [[ "${symbol}" == "${_prompt_keymap_symbol}" ]] && return 0
  _prompt_keymap_symbol="${symbol}"
  zle reset-prompt
  return 0
}

_prompt_keymap_line_init() {
  emulate -L zsh

  [[ -n "${_prompt_keymap_symbol}" ]] || return 0
  _prompt_keymap_symbol=''
  zle reset-prompt
  return 0
}
