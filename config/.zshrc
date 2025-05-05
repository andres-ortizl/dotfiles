zmodload zsh/zprof
setopt HIST_IGNORE_ALL_DUPS
bindkey -e

WORDCHARS=${WORDCHARS//[\/]}




# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh


# ------------------------------

# Post-init module configuration
# ------------------------------

#
# zsh-history-substring-search
#

#zmodload -F zsh/terminfo +p:terminfo
# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
#for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
#for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
#for key ('k') bindkey -M vicmd ${key} history-substring-search-up
#for key ('j') bindkey -M vicmd ${key} history-substring-search-down
#unset key
# }}} End configuration added by Zim install


#[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
#[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export DOTFILES=/Users/andresortiz/code/dotfiles/
source $DOTFILES/shell/main.sh


. "$HOME/.atuin/bin/env"

source ${ZIM_HOME}/modules/zsh-defer/zsh-defer.plugin.zsh

zsh-defer _evalcache direnv hook zsh
_evalcache starship init zsh
zsh-defer _evalcache zoxide init zsh
zsh-defer _evalcache atuin init --disable-up-arrow zsh



#autoload -Uz compinit
#zstyle ':completion:*' menu select
#fpath+=~/.zfunc


#fpath+=~/.zfunc; autoload -Uz compinit; compinit
