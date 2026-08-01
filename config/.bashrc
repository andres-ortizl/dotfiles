PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
if [[ -z "$DOTFILES" ]] && [[ -d "$HOME/code/dotfiles" ]]; then
  export DOTFILES="$HOME/code/dotfiles"
fi
source $DOTFILES/shell/main.sh

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
if [[ "$(uname -s)" == "Darwin" ]]; then
  PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
fi
. "$HOME/.cargo/env"
export PATH

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# >>> lean-ctx agent aliases >>>
alias claude='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" claude'
alias codebuddy='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" codebuddy'
alias codex='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" codex'
alias gemini='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" gemini'
# <<< lean-ctx agent aliases <<<
