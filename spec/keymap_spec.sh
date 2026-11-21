# shellcheck shell=sh

Describe '_prompt_keymap_select'
BeforeEach 'load_plugin' 'stub_zle' '_prompt_keymap_symbol=""'

It 'shows the command symbol in the vi command keymap'
KEYMAP=vicmd
_prompt_keymap_select
The variable _prompt_keymap_symbol should eq '❮'
The variable ZLE_CALLS should eq 'reset-prompt;'
End

It 'keeps the normal symbol in the insert keymap'
KEYMAP=viins
_prompt_keymap_select
The variable _prompt_keymap_symbol should eq ''
The variable ZLE_CALLS should eq ''
End

It 'restores the normal symbol when the line starts'
_prompt_keymap_symbol='❮'
_prompt_keymap_line_init
The variable _prompt_keymap_symbol should eq ''
The variable ZLE_CALLS should eq 'reset-prompt;'
End
End
