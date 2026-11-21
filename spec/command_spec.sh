# shellcheck shell=sh disable=SC2154

Describe 'prompt command info'
BeforeEach 'load_plugin'

Describe '_prompt_duration'
Parameters
0.04 '0.0s'
1.26 '1.3s'
59 '59.0s'
65 '1m5s'
3725 '1h2m5s'
End

It "formats $1 as $2"
When call _prompt_duration "$1"
The value "${REPLY}" should eq "$2"
End
End

Describe '_prompt_exit_label'
It 'keeps ordinary exit codes'
When call _prompt_exit_label 1
The value "${REPLY}" should eq 1
End

It 'names signals above 128'
When call _prompt_exit_label 130
The value "${REPLY}" should eq INT
End
End

Describe '_prompt_pipeline_failed'
It 'ignores a single status'
When call _prompt_pipeline_failed 1
The status should be failure
End

It 'detects a failing earlier stage'
When call _prompt_pipeline_failed 1 0
The status should be success
End

It 'ignores SIGPIPE (141) in earlier stages'
When call _prompt_pipeline_failed 141 0
The status should be failure
End
End

Describe '_prompt_command_update'
It 'does nothing without a recorded start'
_prompt_start_time=-1
When call _prompt_command_update 1 1
The value "${_prompt_command_info}" should eq ''
End

It 'shows the exit code and turns the symbol red on failure'
_prompt_start_time="${EPOCHREALTIME}"
When call _prompt_command_update 2 2
The value "${_prompt_command_info}" should include '2'
The value "${_prompt_status_color}" should eq '%F{red}'
End

It 'stays quiet for a fast successful command'
_prompt_start_time="${EPOCHREALTIME}"
When call _prompt_command_update 0 0
The value "${_prompt_command_info}" should eq ''
The value "${_prompt_status_color}" should eq '%F{green}'
End
End
End

Describe '_prompt_precmd_capture'
It 'stores the status of the command that just ran'
capture() {
  load_plugin
  source "${SHELLSPEC_PROJECT_ROOT}/prompt.plugin.zsh" 2> /dev/null
  false | true
  _prompt_precmd_capture
  print -r -- "${_prompt_exit_code} ${_prompt_pipe_status[*]}"
}
When call capture
The output should eq '0 1 0'
End
End
