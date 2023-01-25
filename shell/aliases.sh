# Enable aliases to be sudo’ed
alias sudo='sudo '

alias ..="cd .."
alias ...="cd ../.."
alias ll="lsd -l"
alias la="lsd -la"
alias ls="lsd"
alias ~="cd ~"
alias vim="nvim"
alias vi="nvim"

# Git
alias gl="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gaa="git add -A"
alias gca="git add --all && git commit --amend --no-edit"
alias gco="git checkout"
alias gs="git status -sb"
alias gf="git fetch --all -p"
alias gps="git push"
alias gpsf="git push --force"
alias gpl="git pull --rebase --autostash"
alias gb="git branch"
alias gcb="git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D"

# Utils
alias k=kubectl
alias cat=bat
alias p.='(pycharm $PWD &>/dev/null &)'
alias c.='(code $PWD &>/dev/null &)'
alias o.='open .'
alias s3ls="aws --profile=mgmt s3 ls"
alias s3cp="aws --profile=mgmt s3 cp"
alias top="htop -s PERCENT_MEM"
alias stree="du --max-depth=n -h | sort --human-numeric-sort"

alias axpipenv="arch -x86_64 /opt/homebrew/bin/pipenv"
