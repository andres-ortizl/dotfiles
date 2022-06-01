function test_dotfiles() {
  echo "Hello world"
}

function measure_performance_shell() {
  # shellcheck disable=SC2034
  for i in $(seq 1 10); do time zsh -i -c exit; done
}



function j() {
  fname=$(declare -f -F _z)

  [ -n "$fname" ] || source "$MYPYDOTFILES/modules/z/z.sh"

  _z "$1"
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
}

function vpn-login() {
  OP_USER_NAME="andres.ortiz"
  OP_CRED_NAME="Clarity VPN login"
  OP_HOST="clarity.1password.com"
  CRED_FILE="${HOME}/.vpn/credentials.txt"

  rm "${CRED_FILE}"
  read -rs OP_PW
  eval "$(echo "${OP_PW}" | op signin ${OP_HOST})"
  PW=$(op get item "${OP_CRED_NAME}" | jq -r '.details.fields[1].value')$(op get totp "${OP_CRED_NAME}")
  echo -e "${OP_USER_NAME}\n${PW}" > "${CRED_FILE}"
	sudo openvpn "${HOME}/.vpn/${OP_USER_NAME}.ovpn"
	rm "${CRED_FILE}"
}

function dc(){
  if docker ps >/dev/null 2>&1; then
  container=$(docker ps | awk '{if (NR!=1) print $1 ": " $(NF)}' | fzf --height 40%)

  if [[ -n $container ]]; then
    container_id=$(echo $container | awk -F ': ' '{print $1}')

    docker exec -it $container_id /bin/bash || docker exec -it $container_id /bin/sh
  else
    echo "You haven't selected any container! ༼つ◕_◕༽つ"
  fi
else
  echo "Docker daemon is not running! (ಠ_ಠ)"
fi
}

function ds(){
  if docker ps >/dev/null 2>&1; then
  container=$(docker ps | awk '{if (NR!=1) print $1 ": " $(NF)}' | fzf --height 40%)

  if [[ -n $container ]]; then
    container_id=$(echo $container | awk -F ': ' '{print $1}')

    docker stop $container_id
  else
    echo "You haven't selected any container! ༼つ◕_◕༽つ"
  fi
else
  echo "Docker daemon is not running! (ಠ_ಠ)"
fi
}