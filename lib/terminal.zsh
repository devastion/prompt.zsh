if [[ -z "${PROMPT_TERMINAL_INTEGRATION-}" ]]; then
  [[ "${TERM}" == 'linux' ]] && PROMPT_TERMINAL_INTEGRATION=0 || PROMPT_TERMINAL_INTEGRATION=1
fi
typeset -gi PROMPT_TERMINAL_INTEGRATION
typeset -gi _prompt_terminal_running=0
typeset -g _prompt_terminal_cwd='' _prompt_terminal_cwd_url=''
typeset -g _prompt_terminal_start='' _prompt_terminal_end=''

_prompt_terminal_marks() {
  if ((PROMPT_TERMINAL_INTEGRATION)); then
    _prompt_terminal_start=$'%{\e]133;A\e\\%}'
    _prompt_terminal_end=$'%{\e]133;B\e\\%}'
  else
    _prompt_terminal_start=''
    _prompt_terminal_end=''
  fi
}
_prompt_terminal_marks

_prompt_terminal_title() {
  emulate -L zsh

  local title="${1%%$'\n'*}"
  title="${title//[[:cntrl:]]/}"
  print -rn -- $'\e]2;'"${title[1,80]}"$'\a'
}

_prompt_terminal_report_cwd() {
  emulate -L zsh +o multibyte

  if [[ "${PWD}" != "${_prompt_terminal_cwd}" ]]; then
    local char byte encoded=''
    for char in "${(@s::)PWD}"; do
      if [[ "${char}" == [A-Za-z0-9/._~-] ]]; then
        encoded+="${char}"
      else
        printf -v byte '%%%02X' "'${char}"
        encoded+="${byte}"
      fi
    done
    _prompt_terminal_cwd="${PWD}"
    _prompt_terminal_cwd_url="file://${HOST}${encoded}"
  fi
  print -rn -- $'\e]7;'"${_prompt_terminal_cwd_url}"$'\e\\'
}

_prompt_terminal_preexec() {
  emulate -L zsh

  ((PROMPT_TERMINAL_INTEGRATION)) || return 0
  _prompt_terminal_running=1
  print -rn -- $'\e]133;C\e\\'
  local -a words=("${(@z)1}")
  while [[ "${words[1]-}" == *=* ]]; do
    shift words
  done
  _prompt_terminal_title "${words[1]-}"
}

_prompt_terminal_precmd() {
  emulate -L zsh

  _prompt_terminal_marks
  ((PROMPT_TERMINAL_INTEGRATION)) || return 0
  if ((_prompt_terminal_running)); then
    _prompt_terminal_running=0
    print -rn -- $'\e]133;D;'"${1}"$'\e\\'
  fi
  _prompt_terminal_report_cwd
  if _prompt_is_ssh; then
    _prompt_terminal_title "${(%):-%n@%m: %~}"
  else
    _prompt_terminal_title "${(%):-%~}"
  fi
}
