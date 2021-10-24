function cdd() {
  cd "$(ls -d -- */ | fzf)" || echo "Invalid directory"
}

function j() {
  fname=$(declare -f -F _z)

  [ -n "$fname" ] || source "$DOTLY_PATH/modules/z/z.sh"

  _z "$1"
}

function recent_dirs() {
  # This script depends on pushd. It works better with autopush enabled in ZSH
  escaped_home=$(echo $HOME | sed 's/\//\\\//g')
  selected=$(dirs -p | sort -u | fzf)

  cd "$(echo "$selected" | sed "s/\~/$escaped_home/")" || echo "Invalid directory"
}

function reverse-search() {
  local selected num
  setopt localoptions noglobsubst noposixbuiltins pipefail HIST_FIND_NO_DUPS 2> /dev/null

  selected=( $(fc -rl 1 |
    FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} $FZF_DEFAULT_OPTS -n2..,.. --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS --query=${(qqq)LBUFFER} +m" fzf) )
  local ret=$?
  if [ -n "$selected" ]; then
    num=$selected[1]
    if [ -n "$num" ]; then
      zle vi-fetch-history -n $num
    fi
  fi
  zle redisplay
  typeset -f zle-line-init >/dev/null && zle zle-line-init
  return $ret
}


function kubeconfig() {
    KUBEHOME=~/.kube

    setopt +o nomatch
    for filename in ${KUBEHOME}/configs/**; do
        if [[ -z "${KUBECONFIG}" ]]; then
            export KUBECONFIG=${filename}
        else
            export KUBECONFIG=${filename}:${KUBECONFIG}
        fi
    done
    # NOTE: Automatically generated config for docker kubernetes
    KUBECONFIG=${KUBECONFIG}:${KUBEHOME}/config
    
    source <(kubectl completion zsh)
    source $DOTFILES_PATH/shell/kube-ps1.sh
    PROMPT='$(kube_ps1)'$PROMPT
}


function vpn-login {
  OP_USER_NAME="andres.ortiz"
  OP_CRED_NAME="Clarity VPN login"
  OP_HOST="clarity.1password.com"
  CRED_FILE="${HOME}/.vpn/credentials.txt"

  read -rs OP_PW
  eval "$(echo "${OP_PW}" | op signin ${OP_HOST})"
  PW=$(op get item "${OP_CRED_NAME}" | jq -r '.details.fields[1].value')$(op get totp "${OP_CRED_NAME}")
  echo -e "${OP_USER_NAME}\n${PW}" > "${CRED_FILE}"
	sudo openvpn "${HOME}/.vpn/${OP_USER_NAME}.ovpn"
	rm "${CRED_FILE}"
}