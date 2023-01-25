PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
