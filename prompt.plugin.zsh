0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}

typeset -g _prompt_dir="${0:h}"

if [[ "${TERM}" == 'dumb' ]]; then
  PROMPT='$ '
  return
fi

autoload -Uz add-zsh-hook add-zle-hook-widget
setopt prompt_subst
zmodload zsh/datetime
zmodload -F zsh/system p:sysparams 2> /dev/null

typeset -g PROMPT_SYMBOL="${PROMPT_SYMBOL:-"❯"}"
typeset -gi _prompt_drawn=0
typeset -g _prompt_keymap_symbol=''

typeset -g _prompt_ssh_indicator=''
typeset -g _prompt_nested_shell_indicator=''
typeset -g _prompt_nix_indicator=' %F{cyan} nix%f'
typeset -g _prompt_direnv_indicator=' %F{magenta}󱁿 direnv%f'

_prompt_is_ssh() { [[ -n "${SSH_CONNECTION-}${SSH_TTY-}${SSH_CLIENT-}" ]]; }

if _prompt_is_ssh; then
  _prompt_ssh_indicator='%F{yellow}%n%F{7}@%F{green}%m%f '
fi

if [[ "${PPID}" == "${ZSH_INTERACTIVE_PID}" ]]; then
  _prompt_nested_shell_indicator='%F{yellow}▸%f '
fi
export ZSH_INTERACTIVE_PID=$$

for _prompt_file in command git terminal transient; do
  source "${_prompt_dir}/lib/${_prompt_file}.zsh"
done
unset _prompt_file

_prompt_precmd() {
  local exit_code="${?}" pipe_status=("$pipestatus[@]")
  emulate -L zsh

  _prompt_terminal_precmd "${exit_code}"
  _prompt_transient_restore

  if ((_prompt_drawn)); then
    print
  else
    _prompt_drawn=1
  fi

  _prompt_command_update "${exit_code}" "$pipe_status[@]"
  _prompt_git_update
}

add-zsh-hook preexec _prompt_command_start
add-zsh-hook preexec _prompt_terminal_preexec
add-zsh-hook precmd _prompt_precmd
add-zsh-hook zshexit _prompt_git_cancel
add-zle-hook-widget line-finish _prompt_line_finish
add-zle-hook-widget line-init _prompt_line_init

PROMPT='${_prompt_terminal_start}${_prompt_ssh_indicator}%B%F{blue}%~%f%b${_prompt_git_status}${_prompt_command_info}%(1j. %F{cyan}⚙%j%f.)'
PROMPT+=$'\n''${_prompt_nested_shell_indicator}${_prompt_status_color}${_prompt_keymap_symbol:-${PROMPT_SYMBOL}}%f ${_prompt_terminal_end}'
RPROMPT=$'%{\e[1A%}''${DIRENV_DIR:+${_prompt_direnv_indicator}}${IN_NIX_SHELL:+${_prompt_nix_indicator}}'$'%{\e[1B%}'
