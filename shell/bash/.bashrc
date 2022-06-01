PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
export MYPYDOTFILES=/Users/andrew/.mypydotfiles
source $MYPYDOTFILES/shell/main.sh
