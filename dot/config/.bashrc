PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export DOTFILES=/Users/andresortiz/code/dotfiles/dot
source $DOTFILES/shell/main.sh
PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
. "$HOME/.cargo/env"export
