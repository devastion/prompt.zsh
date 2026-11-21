typeset -gF PROMPT_MIN_DURATION="${PROMPT_MIN_DURATION:-"2.0"}"

typeset -gF _prompt_start_time=-1
typeset -gi _prompt_command_piped=0
typeset -g _prompt_command_info=''
typeset -g _prompt_status_color='%F{green}'

_prompt_duration() {
  emulate -L zsh

  local -F seconds="${1}"
  local -i deciseconds=$((seconds * 10 + 0.5))
  local -i total_seconds=$((deciseconds / 10))
  local -i hours=$((total_seconds / 3600))
  local -i minutes=$(((total_seconds % 3600) / 60))
  local -i remaining_seconds=$((total_seconds % 60))

  if ((hours)); then
    REPLY="${hours}h${minutes}m${remaining_seconds}s"
  elif ((minutes)); then
    REPLY="${minutes}m${remaining_seconds}s"
  else
    REPLY="${remaining_seconds}.$((deciseconds % 10))s"
  fi
}

_prompt_exit_label() {
  emulate -L zsh

  local -i code="${1}"
  local signal_name
  REPLY="${code}"
  ((code > 128)) || return 0
  signal_name="$signals[code-127]"
  [[ -n "${signal_name}" && "${signal_name}" != (ZERR|DEBUG) ]] && REPLY="${signal_name}"
  return 0
}

_prompt_command_start() {
  emulate -L zsh

  _prompt_start_time="${EPOCHREALTIME}"
  [[ "${1}" == *'|'* ]] && _prompt_command_piped=1 || _prompt_command_piped=0
}

_prompt_pipeline_failed() {
  emulate -L zsh

  local -a stages=("$@")
  (($# > 1)) || return 1
  [[ "${(j::)${(@)stages[1,-2]:#141}}${stages[-1]}" == *[1-9]* ]]
}

_prompt_command_update() {
  emulate -L zsh

  local -i exit_code="${1}"
  local -F elapsed
  local -a info=() labels=()
  local REPLY code
  shift

  _prompt_status_color='%F{green}'
  _prompt_command_info=''

  ((_prompt_start_time >= 0)) || return 0
  elapsed=$((EPOCHREALTIME - _prompt_start_time))
  _prompt_start_time=-1

  ((exit_code)) && _prompt_status_color='%F{red}'
  if ((_prompt_command_piped)) && [[ "${@[-1]-}" == "${exit_code}" ]] &&
    _prompt_pipeline_failed "$@"; then
    for code in "$@"; do
      _prompt_exit_label "${code}"
      labels+=("${REPLY}")
    done
    info+=("%F{red}${(j:|:)labels}%f")
  elif ((exit_code)); then
    _prompt_exit_label "${exit_code}"
    info+=("%F{red}${REPLY}%f")
  fi
  if ((elapsed >= PROMPT_MIN_DURATION)); then
    _prompt_duration "${elapsed}"
    info+=("%F{yellow}${REPLY}%f")
  fi
  ((${#info})) && _prompt_command_info=" ${(j: :)info}"
  return 0
}
