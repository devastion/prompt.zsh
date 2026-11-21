# shellcheck shell=sh disable=SC2296,SC2154

Describe 'prompt git helpers'
  BeforeEach 'load_plugin'

  Describe '_prompt_git_locate'
    It 'finds the repository root and .git directory'
      locate() {
        mkdir -p "${SHELLSPEC_TMPBASE}/proj/.git" "${SHELLSPEC_TMPBASE}/proj/a/b"
        cd "${SHELLSPEC_TMPBASE}/proj/a/b" && _prompt_git_locate && print -r -- "${(j:|:)reply}"
      }
      When call locate
      The output should end with 'proj|'"${SHELLSPEC_TMPBASE}/proj/.git"
    End

    It 'follows a gitdir file (worktrees, submodules)'
      locate() {
        mkdir -p "${SHELLSPEC_TMPBASE}/wt"
        print -r -- 'gitdir: /elsewhere/.git/worktrees/wt' > "${SHELLSPEC_TMPBASE}/wt/.git"
        cd "${SHELLSPEC_TMPBASE}/wt" && _prompt_git_locate && print -r -- "${reply[2]}"
      }
      When call locate
      The output should eq '/elsewhere/.git/worktrees/wt'
    End

    It 'uses GIT_DIR and GIT_WORK_TREE when set'
      locate() {
        mkdir -p "${SHELLSPEC_TMPBASE}/bare.git" "${SHELLSPEC_TMPBASE}/elsewhere"
        cd "${SHELLSPEC_TMPBASE}/elsewhere" || return
        GIT_DIR="${SHELLSPEC_TMPBASE}/bare.git" GIT_WORK_TREE="${SHELLSPEC_TMPBASE}/home" _prompt_git_locate &&
          print -r -- "${reply[1]}"
      }
      When call locate
      The output should eq 'home'
    End

    It 'fails outside a repository'
      locate() { cd / && _prompt_git_locate; }
      When call locate
      The status should be failure
    End
  End

  Describe '_prompt_git_action'
    Parameters
      rebase-merge rebase
      MERGE_HEAD merge
      CHERRY_PICK_HEAD cherry-pick
      REVERT_HEAD revert
      BISECT_LOG bisect
      none ''
    End

    It "reports '$2' for $1"
      action() {
        local d="${SHELLSPEC_TMPBASE}/gd"
        rm -rf "${d}"; mkdir -p "${d}"
        case "$1" in
          rebase-merge) mkdir -p "${d}/rebase-merge" ;;
          none) ;;
          *) : > "${d}/$1" ;;
        esac
        _prompt_git_action "${d}"
        print -r -- "${REPLY}"
      }
      When call action "$1"
      The output should eq "$2"
    End
  End

  Describe '_prompt_git_config cache'
    It 'rereads the config when the file changes'
      reread() {
        mkdir -p "${SHELLSPEC_TMPBASE}/gc"
        printf '%s\n' '[core]' > "${SHELLSPEC_TMPBASE}/gc/config"
        _prompt_git_config "${SHELLSPEC_TMPBASE}/gc" && print -r -- "${REPLY//$'\n'/|}"
        printf '%s\n' '[remote "origin"]' > "${SHELLSPEC_TMPBASE}/gc/config"
        _prompt_git_config "${SHELLSPEC_TMPBASE}/gc" && print -r -- "${REPLY//$'\n'/|}"
      }
      When call reread
      The line 1 of output should eq '|[core]'
      The line 2 of output should eq '|[remote "origin"]'
    End
  End

  Describe '_prompt_git_has_remote'
    check() {
      mkdir -p "${SHELLSPEC_TMPBASE}/gd"
      printf '%s\n' "$1" > "${SHELLSPEC_TMPBASE}/gd/config"
      _prompt_git_has_remote "${SHELLSPEC_TMPBASE}/gd"
    }

    It 'detects a remote section'
      When call check '[remote "origin"]'
      The status should be success
    End

    It 'fails without a remote'
      When call check '[core]'
      The status should be failure
    End
  End

  Describe '_prompt_git_restricted'
    check() {
      mkdir -p "${SHELLSPEC_TMPBASE}/gd"
      printf '%s\n' "$1" > "${SHELLSPEC_TMPBASE}/gd/config"
      _prompt_git_restricted "${SHELLSPEC_TMPBASE}/gd"
    }

    It 'flags configs with a filter section'
      When call check '[filter "lfs"]'
      The status should be success
    End

    It 'flags configs with includeIf'
      When call check '[includeIf "gitdir:~/"]'
      The status should be success
    End

    It 'accepts plain configs'
      When call check '[core]'
      The status should be failure
    End
  End

  Describe '_prompt_git_head'
    head_for() {
      mkdir -p "${SHELLSPEC_TMPBASE}/gd"
      printf '%s\n' "$1" > "${SHELLSPEC_TMPBASE}/gd/HEAD"
      _prompt_git_head "${SHELLSPEC_TMPBASE}/gd"
      print -r -- "${_prompt_git_status}"
    }

    It 'shows the branch name'
      When call head_for 'ref: refs/heads/feature/x'
      The output should include 'feature/x'
    End

    It 'marks a detached HEAD'
      When call head_for 'abcdef1234567890'
      The output should include 'abcdef1'
    End
  End
End

Describe 'prompt transient'
  BeforeEach 'load_plugin'

  It 'restores the full prompt once'
    restore() {
      PROMPT='short'
      _prompt_full_prompt='full'
      _prompt_transient_active=1
      _prompt_transient_restore
      print -r -- "${PROMPT}|${_prompt_transient_active}"
    }
    When call restore
    The output should eq 'full|0'
  End

  It 'leaves the prompt alone when not transient'
    restore() {
      PROMPT='same'
      _prompt_full_prompt='full'
      _prompt_transient_active=0
      _prompt_transient_restore
      print -r -- "${PROMPT}"
    }
    When call restore
    The output should eq 'same'
  End
End
