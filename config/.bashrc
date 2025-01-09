PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export DOTFILES=/Users/andresortiz/code/dotfiles/
source $DOTFILES/shell/main.sh
PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
. "$HOME/.cargo/env"export

source /Users/andresortiz/.docker/init-bash.sh || true # Added by Docker Desktop

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
eval "$(atuin init bash)"
