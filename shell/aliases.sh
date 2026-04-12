# Navigation
alias sudo=’sudo ‘
alias ..="cd .."
alias ...="cd ../.."
alias ~="cd ~"

# Files
alias ls="eza --icons --group-directories-first"
alias ll="eza -l --icons --group-directories-first"
alias la="eza -la --icons --group-directories-first"
alias lt="eza --tree --icons --group-directories-first --level=2"

# Editors
alias vim="micro"
alias vi="micro"
alias nano="micro"

# Git
alias gl="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gaa="git add -A"
alias gca="git add --all && git commit --amend --no-edit"
alias gco="git checkout"
alias gs="git status -sb"
alias gd="git diff"
alias gdi="lazygit"
alias gf="git fetch --all -p"
alias gps="git push"
alias gpsf="git push --force-with-lease"
alias gpl="git pull --rebase --autostash"
alias gb="git branch"
alias gcb="git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D"
alias gg="gitui"

# Utils
alias k=kubectl
alias lzd=lazydocker
alias cat=bat
alias z.='(zed $PWD &>/dev/null &)'
alias o.='open .'
alias s3ls="aws --profile=mgmt s3 ls"
alias s3cp="aws --profile=mgmt s3 cp"
alias top="btop"
alias stree="du -d 1 -h | sort -h"
alias ports="lsof -iTCP -sTCP:LISTEN -n -P"
alias myip="curl -s ifconfig.me"
alias weather="curl -s wttr.in"
alias memtop="procs --load-config ~/.config/procs/config.toml | head -20"

# Help
alias help-aliases="alias-help"
alias help-functions="func-help"
