# vim:et sts=2 sw=2 ft=zsh

function _prompt_main() {
  # This runs in a subshell
  RETVAL=${?}
  BG_COLOR=''

  _prompt_status
  _prompt_pwd
  _prompt_git
  _prompt_end
}


function _prompt_segment() {
  print -n "%K{${1}}"
  if [[ -n ${BG_COLOR} ]] print -n "%F{${BG_COLOR}}"
  print -n "${2}"
  BG_COLOR=${1}
}

function _prompt_standout_segment() {
  print -n "%S%F{${1}}"
  if [[ -n ${BG_COLOR} ]] print -n "%K{${BG_COLOR}}%k"
  print -n "${2}%s"
  BG_COLOR=${1}
}

function _prompt_end() {
  print -n "%k%F{${BG_COLOR}}%f "
}


function _prompt_status() {
  local segment=''
  if (( RETVAL )) segment+=' %F{red}✘'
  if (( EUID == 0 )) segment+=' %F{yellow}⚡'
  if (( $(jobs -l | wc -l) )) segment+=' %F{cyan}⚙'
  if (( RANGER_LEVEL )) segment+=' %F{cyan}r'
  if [[ -n ${VIRTUAL_ENV} ]] segment+=" %F{cyan}${VIRTUAL_ENV:t}"
  if [[ -n ${SSH_TTY} ]] segment+=" %F{%(!.yellow.default)}%n@%m"
  if [[ -n ${segment} ]]; then
    _prompt_segment ${STATUS_COLOR} "${segment} "
  fi
}

function _prompt_pwd() {
  local current_dir=${(%):-%~}
  if [[ ${current_dir} != '~' ]]; then
    current_dir="${${(@j:/:M)${(@s:/:)current_dir:h}#?}%/}/${current_dir:t}"
  fi
  _prompt_standout_segment ${PWD_COLOR} " ${current_dir} "
}

function _prompt_git() {
  if [[ -n ${git_info} ]]; then
    local git_color
    local git_dirty=${(e)git_info[dirty]}
    if [[ -n ${git_dirty} ]]; then
      git_color=${DIRTY_COLOR}
    else
      git_color=${CLEAN_COLOR}
    fi
    _prompt_standout_segment ${git_color} " ${(e)git_info[prompt]}${git_dirty} "
  fi
}

: ${STATUS_COLOR=black}
: ${PWD_COLOR=cyan}
: ${CLEAN_COLOR=green}
: ${DIRTY_COLOR=yellow}
VIRTUAL_ENV_DISABLE_PROMPT=1

setopt nopromptbang prompt{cr,percent,sp,subst}

if (( ${+functions[git-info]} )); then
  zstyle ':zim:git-info:branch' format ' %b'
  zstyle ':zim:git-info:commit' format '➦ %c'
  zstyle ':zim:git-info:action' format ' (%s)'
  zstyle ':zim:git-info:dirty' format ' ±'
  zstyle ':zim:git-info:keys' format \
      'prompt' '%b%c%s' \
      'dirty' '%D'

  autoload -Uz add-zsh-hook && add-zsh-hook precmd git-info
fi

export RPROMPT="%F{cyan}%@"
PS1='$(_prompt_main)'
unset RPS1
