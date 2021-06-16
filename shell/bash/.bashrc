export DOTFILES_PATH="/Users/andrew/.dotfiles"
export DOTLY_PATH="$DOTFILES_PATH/modules/dotly"

source "$DOTFILES_PATH/shell/init.sh"

PATH=$(
  IFS=":"
  echo "${path[*]}"
)
export PATH

source "$DOTLY_PATH/shell/bash/themes/codely.sh"
export PATH=$PATH:/usr/local/share/dotnet
