typeset -gi PROMPT_TRANSIENT="${PROMPT_TRANSIENT:-"1"}"
typeset -gi _prompt_transient_active=0
typeset -g _prompt_full_prompt=''

_prompt_transient_restore() {
  emulate -L zsh

  if ((_prompt_transient_active)); then
    PROMPT="${_prompt_full_prompt}"
    _prompt_transient_active=0
  fi
  return 0
}

_prompt_line_finish() {
  emulate -L zsh
  setopt prompt_subst

  ((PROMPT_TRANSIENT && ! ZLE_RECURSIVE && ! _prompt_transient_active)) || return 0
  [[ -n "${BUFFER}" && "${CONTEXT}" == 'start' ]] || return 0

  _prompt_full_prompt="${PROMPT}"
  _prompt_transient_active=1

  PROMPT='${_prompt_terminal_start}${_prompt_status_color}${PROMPT_SYMBOL}%f ${_prompt_terminal_end}'
  local RPROMPT=''

  zle reset-prompt
}

_prompt_line_init() {
  emulate -L zsh
  setopt prompt_subst

  if ((_prompt_transient_active)); then
    _prompt_transient_restore
    zle reset-prompt
  fi

  return 0
}
