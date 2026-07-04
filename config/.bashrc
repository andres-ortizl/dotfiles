PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
export DOTFILES=/Users/andrew/code/dotfiles/
source $DOTFILES/shell/main.sh

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
. "$HOME/.cargo/env"export

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"

alias claude-mem='bun "/Users/andrew/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/andrew/.lmstudio/bin"
# End of LM Studio CLI section


# Added by Antigravity CLI installer
export PATH="/Users/andrew/.local/bin:$PATH"

# >>> lean-ctx agent aliases >>>
alias claude='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" claude'
alias codex='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" codex'
alias gemini='LEAN_CTX_AGENT=1 BASH_ENV="$HOME/.bashenv" gemini'
# <<< lean-ctx agent aliases <<<
