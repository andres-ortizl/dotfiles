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
