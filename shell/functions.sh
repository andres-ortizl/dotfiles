function test_dotfiles() {
  echo "Hello world"
}

function measure_performance_shell() {
  hyperfine --warmup 5 "zsh -i -c exit"

}

function j() {
  fname=$(declare -f -F _z)

  [ -n "$fname" ] || source "$DOTFILES/modules/z/z.sh"

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

function fh() {
  eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

function ch() {
  local cols sep
  cols=$(( COLUMNS / 3 ))
  sep='{::}'

  # May change depending on your operating system
  cp -f ~/Library/Application\ Support/Google/Chrome/Default/History /tmp/h

  sqlite3 -separator $sep /tmp/h \
    "select substr(title, 1, $cols), url
     from urls order by last_visit_time desc" |
  awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' |
  fzf --ansi --multi | sed 's#.*\(https*://\)#\1#' | xargs open
}

function psf() {
  FZF_DEFAULT_COMMAND='ps -ef' \
  fzf --bind 'ctrl-r:reload($FZF_DEFAULT_COMMAND)' \
      --header 'Press CTRL-R to reload' --header-lines=1 \
      --height=50% --layout=reverse
}

function rpgrp (){
  INITIAL_QUERY=""
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
  fzf --bind "change:reload:$RG_PREFIX {q} || true" \
      --ansi --disabled --query "$INITIAL_QUERY" \
      --height=50% --layout=reverse
}

function s3csv() {
  aws --profile=mgmt s3 cp "$1" - | bat -l csv
}

function s3json() {
  aws --profile=mgmt s3 cp "$1" - | bat -l json
}


function shit() {
        if [ -n "$1" ]; then
        pro="$1"
    else
        last_command_executed=$(fc -nl -1)
        pro="The following command has been wrongly executed, therefore I want you to fix it and give me the corrected command. Command: $last_command_executed"
    fi

    prompsito="$pro. Keep the response as short as possible, no more than 10 lines.  Respond in Markdown"
    echo "🐑"

    model_llama="llama2"
    model_mistral="mistral:7b"
    raw_data='{
    "prompt": "'${prompsito}'",
    "stream": false,
    "model": "'${model_llama}'"
}'
    api_response=$(curl -s -X POST http://localhost:11434/api/generate -d "$raw_data")
    parsed_response=$(printf "%s" "$api_response" | jq -r '.response')
    bat --language Markdown <<< "$parsed_response"
}
