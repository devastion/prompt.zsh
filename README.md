# prompt.zsh

A two-line zsh prompt in plain zsh, with no dependencies beyond `git`.

- Current directory, and `user@host` over SSH
- Git branch and status, computed asynchronously so the prompt never waits for a large repository
- Duration of slow commands, exit status and pipe status
- Transient prompt: finished prompts collapse to a single line
- Terminal title and OSC 133 prompt marks
- Background job count, a nested-shell marker, and nix-shell and direnv indicators
- The vi-mode keymap shows in the prompt symbol

## Install

```sh
git clone https://github.com/devastion/prompt.zsh.git ~/.zsh/prompt.zsh
echo 'source ~/.zsh/prompt.zsh/prompt.plugin.zsh' >> ~/.zshrc
```

The plugin sets `PROMPT` and `RPROMPT`. With `TERM=dumb` it sets `PROMPT='$ '` and stops.

## Configuration

Set these before sourcing the plugin.

```zsh
PROMPT_SYMBOL='❯'          # symbol on the second line
PROMPT_MIN_DURATION=2.0    # seconds before the command duration shows
```

## Layout

- `prompt.plugin.zsh` sets up the prompt and hooks
- `lib/command.zsh` command duration and status
- `lib/git.zsh` asynchronous Git status
- `lib/terminal.zsh` terminal title and OSC 133 marks
- `lib/transient.zsh` transient prompt

## License

MIT
