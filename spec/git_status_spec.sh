# shellcheck shell=sh disable=SC2296,SC2154

Describe 'prompt git status'
  BeforeEach 'load_plugin' 'stub_zle'

  Describe '_prompt_git_render'
    setup() {
      _prompt_git_dir="${SHELLSPEC_TMPBASE}/none"
      _prompt_git_name=proj
      _prompt_git_status=''
    }
    BeforeEach 'setup'

    render() {
      _prompt_git_render "$1"
      print -r -- "${_prompt_git_status}"
    }

    It 'marks a clean tracked branch'
      input="$(printf '# branch.oid abc\n# branch.head main\n# branch.upstream origin/main\n# branch.ab +0 -0')"
      When call render "${input}"
      The output should include 'proj'
      The output should include 'main'
      The output should not include '+'
      The value "${_prompt_git_clean}" should eq 1
    End

    It 'shows counts for each kind of change'
      input="$(printf '# branch.oid abc\n# branch.head main\n# branch.upstream o/m\n# branch.ab +2 -3\n# stash 1\n1 M. N 1 1 1 a b f\n1 .M N 1 1 1 a b g\n? h\nu UU N 1 1 1 1 a b c i')"
      When call render "${input}"
      The output should include '+1'
      The output should include '!1'
      The output should include '?1'
      The output should include '=1'
      The output should include '*1'
      The output should include '⇡2'
      The output should include '⇣3'
      The value "${_prompt_git_clean}" should eq 0
    End

    It 'abbreviates a detached HEAD'
      input="$(printf '# branch.oid 1234567890\n# branch.head (detached)')"
      When call render "${input}"
      The output should include 'HEAD (1234567)'
    End

    It 'shows "gone" when the upstream vanished'
      input="$(printf '# branch.oid abc\n# branch.head main\n# branch.upstream o/m')"
      When call render "${input}"
      The output should include 'gone'
    End

    It 'escapes percent signs in the branch name'
      input="$(printf '# branch.oid abc\n# branch.head 100%%\n# branch.upstream o/m\n# branch.ab +0 -0')"
      When call render "${input}"
      The output should include '100%%'
    End

    It 'clears the status when the input is not a repository'
      _prompt_git_status=old
      When call render 'garbage'
      The output should eq ''
      The status should be success
    End

    It 'never calls the tree clean when limited'
      limited() {
        _prompt_git_render "$(printf '# branch.oid abc\n# branch.head main')" 1
        print -r -- "${_prompt_git_clean}|${_prompt_git_status}"
      }
      When call limited
      The output should start with '0|'
      The output should include '⚠'
    End
  End

  Describe 'trust helpers'
    It 'is untrusted without a git dir'
      _prompt_git_dir=''
      When call _prompt_git_trusted
      The status should be failure
    End

    It 'is untrusted when limited'
      _prompt_git_dir=/x _prompt_git_limited=1
      When call _prompt_git_trusted
      The status should be failure
    End

    It 'is trusted for a normal repository'
      _prompt_git_dir=/x _prompt_git_limited=0
      When call _prompt_git_trusted
      The status should be success
    End

    It 'reports a clean tree only when trusted and clean'
      _prompt_git_dir=/x _prompt_git_limited=0 _prompt_git_clean=1
      When call _prompt_git_clean_tree
      The status should be success
    End

    It 'does not report a dirty tree as clean'
      _prompt_git_dir=/x _prompt_git_limited=0 _prompt_git_clean=0
      When call _prompt_git_clean_tree
      The status should be failure
    End
  End

  Describe '_prompt_git_update'
    make_repo() {
      REPO="${SHELLSPEC_TMPBASE}/repo"
      rm -rf "${REPO}"
      mkdir -p "${REPO}"
      git -C "${REPO}" init -q -b main
      git -C "${REPO}" config user.email t@example.com
      git -C "${REPO}" config user.name t
      git -C "${REPO}" commit -q --allow-empty -m init
    }

    It 'clears state outside a repository'
      outside() {
        _prompt_git_status=old _prompt_git_dir=/old
        cd / && _prompt_git_update
        print -r -- "[${_prompt_git_status}][${_prompt_git_dir}]"
      }
      When call outside
      The output should eq '[][]'
    End

    It 'renders from .git/HEAD when the config is restricted'
      limited() {
        make_repo
        printf '[filter "lfs"]\n' >> "${REPO}/.git/config"
        cd "${REPO}" && _prompt_git_update
        print -r -- "${_prompt_git_limited}|${_prompt_git_status}"
      }
      When call limited
      The output should start with '1|'
      The output should include 'main'
    End

    It 'starts an async status job and renders its result'
      async() {
        make_repo
        : > "${REPO}/new-file"
        cd "${REPO}" && _prompt_git_update || return
        _prompt_git_callback "${_prompt_git_fd}"
        print -r -- "${_prompt_git_status}"
      }
      When call async
      The output should include 'main'
      The output should include '?1'
      The value "${ZLE_CALLS}" should include '-F'
    End

    It 'cancels a pending job'
      cancel() {
        make_repo
        cd "${REPO}" && _prompt_git_update
        _prompt_git_cancel
        print -r -- "[${_prompt_git_fd}][${_prompt_git_pid}]"
      }
      When call cancel
      The output should eq '[][]'
    End
  End
End

Describe 'prompt transient widgets'
  BeforeEach 'load_plugin' 'stub_zle'

  setup() {
    PROMPT='full' PROMPT_TRANSIENT=1 ZLE_RECURSIVE=0
    BUFFER='ls' CONTEXT=start
    _prompt_transient_active=0
  }
  BeforeEach 'setup'

  It 'swaps in the short prompt on line-finish'
    finish() {
      _prompt_line_finish
      print -r -- "${_prompt_transient_active}|${_prompt_full_prompt}|${PROMPT}"
    }
    When call finish
    The output should start with '1|full|'
    The output should include 'PROMPT_SYMBOL'
    The value "${ZLE_CALLS}" should eq 'reset-prompt;'
  End

  It 'does nothing for an empty buffer'
    BUFFER=''
    When call _prompt_line_finish
    The value "${_prompt_transient_active}" should eq 0
    The value "${PROMPT}" should eq full
  End

  It 'does nothing when PROMPT_TRANSIENT is off'
    PROMPT_TRANSIENT=0
    When call _prompt_line_finish
    The value "${_prompt_transient_active}" should eq 0
  End

  It 'does nothing outside the start context'
    CONTEXT=cont
    When call _prompt_line_finish
    The value "${_prompt_transient_active}" should eq 0
  End

  It 'restores the full prompt on line-init'
    init() {
      _prompt_line_finish
      _prompt_line_init
      print -r -- "${_prompt_transient_active}|${PROMPT}"
    }
    When call init
    The output should eq '0|full'
    The value "${ZLE_CALLS}" should eq 'reset-prompt;reset-prompt;'
  End
End
