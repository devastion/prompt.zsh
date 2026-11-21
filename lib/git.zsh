typeset -g _prompt_git_status=''
typeset -g _prompt_git_fd='' _prompt_git_pid='' _prompt_git_dir='' _prompt_git_name=''
typeset -gi _prompt_git_limited=0 _prompt_git_clean=0
typeset -gA _prompt_git_config_cache=()

_prompt_git_locate() {
  emulate -L zsh

  local dir="${PWD}" git_dir
  # An explicit GIT_DIR (dotfile bare repos, scripts) overrides the search.
  if [[ -n "${GIT_DIR-}" ]]; then
    git_dir="${GIT_DIR:A}"
    [[ -d "${git_dir}" ]] || return 1
    dir="${GIT_WORK_TREE:-${git_dir:h}}"
    reply=("${dir:t}" "${git_dir}")
    return 0
  fi
  while true; do
    if [[ -d "${dir}/.git" ]]; then
      git_dir="${dir}/.git"
    elif [[ -f "${dir}/.git" ]]; then
      git_dir="$(< "${dir}/.git")"
      git_dir="${git_dir#gitdir: }"
      [[ "${git_dir}" == /* ]] || git_dir="${dir}/${git_dir}"
    fi
    if [[ -n "${git_dir}" ]]; then
      reply=("${dir:t}" "${git_dir}")
      return 0
    fi
    [[ "${dir}" == '/' ]] && return 1
    dir="${dir:h}"
  done
}

_prompt_git_action() {
  emulate -L zsh

  local git_dir="${1}"
  if [[ -d "${git_dir}/rebase-merge" ]]; then
    REPLY='rebase'
  elif [[ -f "${git_dir}/rebase-apply/applying" ]]; then
    REPLY='am'
  elif [[ -d "${git_dir}/rebase-apply" ]]; then
    REPLY='rebase'
  elif [[ -f "${git_dir}/MERGE_HEAD" ]]; then
    REPLY='merge'
  elif [[ -f "${git_dir}/CHERRY_PICK_HEAD" ]]; then
    REPLY='cherry-pick'
  elif [[ -f "${git_dir}/REVERT_HEAD" ]]; then
    REPLY='revert'
  elif [[ -f "${git_dir}/BISECT_LOG" ]]; then
    REPLY='bisect'
  else
    REPLY=''
  fi
}

# Sets REPLY to the repository config, one leading newline included. Reads are
# cached per file until its modification time or size changes.
_prompt_git_config() {
  emulate -L zsh

  local git_dir="${1}" common="${1}" file stamp
  local -A info
  if [[ -r "${git_dir}/commondir" ]]; then
    common="$(< "${git_dir}/commondir")"
    [[ "${common}" == /* ]] || common="${git_dir}/${common}"
  fi
  file="${common}/config"
  [[ -r "${file}" ]] || return 1
  if ! zstat -H info -- "${file}" 2> /dev/null; then
    # Without a stamp the cache cannot be trusted: read the file directly.
    REPLY=$'\n'"$(< "${file}")"
    return 0
  fi
  stamp="${info[mtime]}:${info[size]}"
  if [[ "${_prompt_git_config_cache[${file}]-}" != "${stamp}"$'\x1f'* ]]; then
    _prompt_git_config_cache[${file}]="${stamp}"$'\x1f'$'\n'"$(< "${file}")"
  fi
  REPLY="${_prompt_git_config_cache[${file}]#*$'\x1f'}"
}

_prompt_git_restricted() {
  emulate -L zsh -o extended_glob

  local git_dir="${1}" REPLY
  _prompt_git_config "${git_dir}" || return 1
  [[ -r "${git_dir}/config.worktree" ]] && REPLY+=$'\n'"$(< "${git_dir}/config.worktree")"
  [[ "${REPLY}" == (#i)*$'\n'[[:blank:]]#'['(filter|include|includeif)([[:blank:].]|']')* ]]
}

_prompt_git_has_remote() {
  emulate -L zsh -o extended_glob

  local REPLY
  _prompt_git_config "${1}" || return 1
  [[ "${REPLY}" == (#i)*$'\n'[[:blank:]]#'[remote '* ]]
}

_prompt_git_head() {
  emulate -L zsh

  local head='' ref
  [[ -r "${1}/HEAD" ]] && head="$(< "${1}/HEAD")"
  if [[ "${head}" == 'ref: '* ]]; then
    ref="${${head#ref: }#refs/heads/}"
    _prompt_git_render $'# branch.oid unknown\n'"# branch.head ${ref}" 1
  else
    _prompt_git_render $'# branch.oid '"${head:-unknown}"$'\n# branch.head (detached)' 1
  fi
}

_prompt_git_render() {
  emulate -L zsh

  local -A git_status=()
  local -i limited="${2:-0}"

  if ! _prompt_git_parse "${1}"; then
    _prompt_git_status=''
    _prompt_git_clean=0
    return 1
  fi

  _prompt_git_clean=$((! limited && git_status[staged] + git_status[unstaged] + \
    git_status[untracked] + git_status[conflicted] == 0))
  _prompt_git_format "${limited}"
}

_prompt_git_parse() {
  emulate -L zsh

  local line
  local -i in_repo=0
  git_status=(
    object_id '' branch '' upstream '' has_ahead_behind 0
    staged 0 unstaged 0 untracked 0 conflicted 0 ahead 0 behind 0 stashed 0
  )

  for line in "${(@f)1}"; do
    case ${line} in
      '1 '* | '2 '*)
        [[ "$line[3]" != . ]] && ((git_status[staged] += 1))
        [[ "$line[4]" != . ]] && ((git_status[unstaged] += 1))
        ;;
      '? '*)
        ((git_status[untracked] += 1))
        ;;
      'u '*)
        ((git_status[conflicted] += 1))
        ;;
      '# branch.oid '*)
        git_status[object_id]="${line#'# branch.oid '}"
        in_repo=1
        ;;
      '# branch.head '*)
        git_status[branch]="${line#'# branch.head '}"
        ;;
      '# branch.upstream '*)
        git_status[upstream]="${line#'# branch.upstream '}"
        ;;
      '# branch.ab '*)
        git_status[has_ahead_behind]=1
        git_status[ahead]="${${line#*+}%% *}"
        git_status[behind]="${line##*-}"
        ;;
      '# stash '*)
        git_status[stashed]="${line#'# stash '}"
        ;;
    esac
  done
  ((in_repo))
}

_prompt_git_format() {
  emulate -L zsh

  local -i limited="${1}" detached=0
  local branch="${git_status[branch]}" object_id="${git_status[object_id]}" REPLY
  local -a reply=()

  if [[ "${branch}" == '(detached)' ]]; then
    detached=1
    branch="HEAD (${object_id[1,7]})"
  fi

  _prompt_git_status=" %F{green}󰘬 ${_prompt_git_name//\%/%%}%f %F{yellow}on%f"
  _prompt_git_status+=" %F{red}${branch//\%/%%}%f"
  _prompt_git_action "${_prompt_git_dir}"
  [[ -n "${REPLY}" ]] && _prompt_git_status+=" %F{yellow}(${REPLY})%f"

  _prompt_git_badges "${limited}" "${detached}"
  ((${#reply})) && _prompt_git_status+=" %B${(j: :)reply}%b"
  return 0
}

_prompt_git_badges() {
  emulate -L zsh

  local -i limited="${1}" detached="${2}"
  reply=()

  ((git_status[staged])) && reply+=("%F{green}+$git_status[staged]%f")
  ((git_status[unstaged])) && reply+=("%F{yellow}!$git_status[unstaged]%f")
  ((git_status[untracked])) && reply+=("%F{cyan}?$git_status[untracked]%f")
  ((git_status[conflicted])) && reply+=("%F{red}=$git_status[conflicted]%f")
  ((git_status[stashed])) && reply+=("%F{white}*$git_status[stashed]%f")
  ((git_status[ahead])) && reply+=("%F{magenta}⇡$git_status[ahead]%f")
  ((git_status[behind])) && reply+=("%F{blue}⇣$git_status[behind]%f")

  if ((limited)); then
    reply+=('%F{red}⚠%f')
  elif ((! detached)); then
    if [[ -z "$git_status[upstream]" ]]; then
      _prompt_git_has_remote "${_prompt_git_dir}" || reply+=('%F{8}⊘%f')
    elif ((! git_status[has_ahead_behind])); then
      reply+=('%F{red}gone%f')
    fi
  fi
  return 0
}

_prompt_git_update() {
  emulate -L zsh

  local -a reply=()

  _prompt_git_cancel
  _prompt_git_clean=0

  if ! _prompt_git_locate; then
    _prompt_git_status=''
    _prompt_git_dir=''
    return 0
  fi

  [[ "$reply[2]" == "${_prompt_git_dir}" ]] || _prompt_git_status=''
  _prompt_git_name="$reply[1]"
  _prompt_git_dir="$reply[2]"

  if _prompt_git_restricted "${_prompt_git_dir}"; then
    _prompt_git_limited=1
    _prompt_git_head "${_prompt_git_dir}"
    return 0
  fi
  _prompt_git_limited=0

  # `exec` makes git the process substitution itself, so its pid is the one
  # to signal when the job is cancelled.
  exec {_prompt_git_fd}< <(
    exec command git -c core.fsmonitor=false --no-optional-locks \
      status --porcelain=v2 --branch --show-stash --ignore-submodules=dirty 2> /dev/null
  )
  _prompt_git_pid="${sysparams[procsubstpid]-}"
  zle -F "${_prompt_git_fd}" _prompt_git_callback
}

_prompt_git_trusted() {
  [[ -n "${_prompt_git_dir}" ]] && ((! _prompt_git_limited))
}

_prompt_git_clean_tree() {
  _prompt_git_trusted && ((_prompt_git_clean))
}

_prompt_git_cancel() {
  emulate -L zsh

  if [[ -n "${_prompt_git_fd}" ]]; then
    zle -F "${_prompt_git_fd}" 2> /dev/null
    exec {_prompt_git_fd}<&-
    _prompt_git_fd=''
    [[ -n "${_prompt_git_pid}" ]] && kill -HUP -- "${_prompt_git_pid}" 2> /dev/null
  fi
  _prompt_git_pid=''
  return 0
}

_prompt_git_callback() {
  emulate -L zsh
  setopt prompt_subst

  local fd="${1}" data

  zle -F "${fd}"
  IFS= read -r -u "${fd}" -d '' data
  exec {fd}<&-
  if [[ "${fd}" == "${_prompt_git_fd}" ]]; then
    _prompt_git_fd=''
    _prompt_git_pid=''
  fi

  _prompt_git_render "${data}"

  if ((! _prompt_transient_active)); then
    zle && zle reset-prompt
  fi

  return 0
}
