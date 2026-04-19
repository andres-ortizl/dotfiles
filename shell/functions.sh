function _load_env() {
  # Load specific environment variable from .env file on-demand
  local var_name="$1"

  if [ -n "${(P)var_name}" ]; then
    return 0
  fi

  if [ -f "$DOTFILES/.env" ]; then
    local value=$(grep "^${var_name}=" "$DOTFILES/.env" | cut -d= -f2- | sed 's/^["'\'']//' | sed 's/["'\'']$//')
    if [ -n "$value" ]; then
      export $var_name="$value"
      return 0
    fi
  fi

  return 1
}

function alias-help() {
  # Show all available aliases
  local md=()
  md+=("| Alias | Command |")
  md+=("| --- | --- |")
  while IFS= read -r line; do
    if [[ "$line" =~ ^alias\  ]]; then
      local name=$(echo "$line" | sed 's/alias //' | cut -d= -f1)
      local cmd=$(echo "$line" | sed "s/alias [^=]*=//" | sed "s/^[\"']//" | sed "s/[\"']$//" | sed 's/|/∣/g' | cut -c1-55)
      md+=("| \`${name}\` | \`${cmd}\` |")
    fi
  done < "$DOTFILES/shell/aliases.sh"

  if command -v gum &>/dev/null; then
    gum style --border rounded --border-foreground 99 --padding "0 1" --bold --foreground 212 " Aliases"
    echo ""
    gum format -- "${md[@]}"
  else
    printf '%s\n' "${md[@]}"
  fi
}

function func-help() {
  # Show all available functions with descriptions
  local md=()
  md+=("| Function | Description |")
  md+=("| --- | --- |")
  while IFS= read -r entry; do
    local fname="${entry%%\|*}"
    local desc="${entry#*\|}"
    md+=("| \`${fname}\` | ${desc} |")
  done < <(awk '/^function / {
    fname = $2;
    sub(/\(\) \{/, "", fname);
    getline;
    if ($0 ~ /^  #/) {
      desc = $0;
      sub(/^  # /, "", desc);
      printf "%s|%s\n", fname, desc;
    }
  }' "$DOTFILES/shell/functions.sh" | grep -v "alias-help\|func-help\|_load_env")

  if command -v gum &>/dev/null; then
    gum style --border rounded --border-foreground 99 --padding "0 1" --bold --foreground 212 " Functions"
    echo ""
    gum format -- "${md[@]}"
  else
    printf '%s\n' "${md[@]}"
  fi
}

function help() {
  # Show all aliases and functions together, or search with fzf
  if [[ "$1" == "-s" ]] || [[ "$1" == "--search" ]]; then
    {
      grep "^alias " "$DOTFILES/shell/aliases.sh" | grep -v "^alias sudo=" | sed 's/alias //' | sed 's/=/ → /'
      awk '/^function / {
        fname = $2; sub(/\(\) \{/, "", fname); getline;
        if ($0 ~ /^  #/) { desc = $0; sub(/^  # /, "", desc); printf "%s → %s\n", fname, desc; }
      }' "$DOTFILES/shell/functions.sh" | grep -v "alias-help\|func-help\|_load_env"
    } | fzf --height=50% --header="Search (ESC to exit)" --bind='enter:execute(echo {} | pbcopy)+abort'
    return
  fi
  alias-help
  echo ""
  func-help
}


function shell-bench() {
  # Quick benchmark of shell startup and alias performance
  if ! command -v hyperfine &> /dev/null; then
    echo "❌ hyperfine not installed. Run: brew install hyperfine"
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    echo "❌ jq not installed. Run: brew install jq"
    return 1
  fi
  echo "🚀 Shell & Alias Benchmark"
  echo "================================"

  # Run benchmarks and capture results
  local results=$(hyperfine --warmup 3 --export-json /tmp/bench.json \
    'zsh -i -c exit' \
    'zsh -i -c "ls"' \
    'zsh -i -c "ll"' 2>&1)

  echo ""
  echo "📊 Performance Analysis"
  echo "================================"

  local startup=$(jq -r '.results[0].mean * 1000 | floor' /tmp/bench.json)
  local ls_time=$(jq -r '.results[1].mean * 1000 | floor' /tmp/bench.json)
  local ll_time=$(jq -r '.results[2].mean * 1000 | floor' /tmp/bench.json)

  local startup_good=100
  local startup_ok=200
  local alias_good=150
  local alias_ok=300

  eval_perf() {
    local name=$1
    local time=$2
    local good=$3
    local ok=$4

    if [[ $time -lt $good ]]; then
      echo "✅ $name: ${time}ms (Excellent)"
    elif [[ $time -lt $ok ]]; then
      echo "⚠️  $name: ${time}ms (Acceptable)"
    else
      echo "❌ $name: ${time}ms (Needs optimization)"
    fi
  }

  eval_perf "Zsh startup" $startup $startup_good $startup_ok
  eval_perf "ls alias   " $ls_time $alias_good $alias_ok
  eval_perf "ll alias   " $ll_time $alias_good $alias_ok

  echo ""
  echo "💡 Recommendations:"
  if [[ $startup -gt $startup_ok ]]; then
    echo "   - Shell startup is slow. Check .zshrc plugins"
  fi
  if [[ $ls_time -gt $alias_ok ]] || [[ $ll_time -gt $alias_ok ]]; then
    echo "   - File listing aliases are slow. Check lsd installation"
  fi
  if [[ $startup -lt $startup_good ]] && [[ $ls_time -lt $alias_good ]] && [[ $ll_time -lt $alias_good ]]; then
    echo "   🎉 All benchmarks are excellent! Keep it up!"
  fi

  rm -f /tmp/bench.json
}

function shell-debug() {
  # Complete debug with profiling and component analysis
  if ! command -v hyperfine &> /dev/null; then
    echo "❌ hyperfine not installed. Run: brew install hyperfine"
    return 1
  fi
  echo "🔍 Zsh Startup Debug"
  echo "===================="

  echo -e "\n📊 Top 10 Slowest Functions:"
  zsh -i -c 'zprof' 2>/dev/null | head -25

  echo -e "\n⏱️  Startup Times:"
  hyperfine --warmup 2 \
    'zsh -c exit' \
    'zsh -i -c exit' \
    --export-markdown /tmp/startup-times.md

  echo -e "\n🔍 Component Loading:"
  hyperfine --warmup 1 \
    "zsh -c 'source $DOTFILES/shell/aliases.sh'" \
    "zsh -c 'source $DOTFILES/shell/exports.sh'" \
    "zsh -c 'source $DOTFILES/shell/functions.sh'"

  echo -e "\n💡 Quick Fixes:"
  echo "   • Lazy load NVM/Node (saves ~300ms)"
  echo "   • Use zsh-defer for heavy tools"
  echo "   • Remove unused plugins from .zimrc"
}



function kubeconfig() {
    # Load all kubeconfig files and enable kubectl/helm completion
    KUBEHOME=~/.kube

    setopt +o nomatch
    for filename in ${KUBEHOME}/configs/**; do
        if [[ -z "${KUBECONFIG}" ]]; then
            export KUBECONFIG=${filename}
        else
            export KUBECONFIG=${filename}:${KUBECONFIG}
        fi
    done
    KUBECONFIG=${KUBECONFIG}:${KUBEHOME}/config
    source <(helm completion zsh)
    source <(kubectl completion zsh)
}
function kubedown() {
    # Unload kubeconfig environment variables and unset current context
    kubectl config unset current-context 2>/dev/null
    unset KUBECONFIG
    unset KUBEHOME
}



function dc(){
  # Interactive docker container exec with fzf selection
  if ! command -v docker &> /dev/null; then
    echo "❌ docker not installed"
    return 1
  fi
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed. Run: brew install fzf"
    return 1
  fi
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
  # Interactive docker container stop with fzf selection
  if ! command -v docker &> /dev/null; then
    echo "❌ docker not installed"
    return 1
  fi
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed. Run: brew install fzf"
    return 1
  fi
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


function ch() {
  # Search Chrome browsing history with fzf and open selected URL
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed. Run: brew install fzf"
    return 1
  fi
  if ! command -v sqlite3 &> /dev/null; then
    echo "❌ sqlite3 not installed"
    return 1
  fi
  local cols sep
  cols=$(( COLUMNS / 3 ))
  sep='{::}'

  cp -f ~/Library/Application\ Support/Google/Chrome/Default/History /tmp/h

  sqlite3 -separator $sep /tmp/h \
    "select substr(title, 1, $cols), url
     from urls order by last_visit_time desc" |
  awk -F $sep '{printf "%-'$cols's  \x1b[36m%s\x1b[m\n", $1, $2}' |
  fzf --ansi --multi | sed 's#.*\(https*://\)#\1#' | xargs open
}



function rpgrp (){
  # Interactive ripgrep search that opens results in Zed editor
  if ! command -v rg &> /dev/null; then
    echo "❌ ripgrep not installed. Run: brew install ripgrep"
    return 1
  fi
  if ! command -v fzf &> /dev/null; then
    echo "❌ fzf not installed. Run: brew install fzf"
    return 1
  fi
  if ! command -v zed &> /dev/null; then
    echo "❌ zed not installed"
    return 1
  fi
  INITIAL_QUERY=""
  RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
  local selected=$(FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY'" \
    fzf --bind "change:reload:$RG_PREFIX {q} || true" \
        --ansi --disabled --query "$INITIAL_QUERY" \
        --height=50% --layout=reverse)

  if [[ -n "$selected" ]]; then
    local file=$(echo "$selected" | cut -d: -f1)
    local line=$(echo "$selected" | cut -d: -f2)
    zed "$file:$line"
  fi
}

function s3csv() {
  # View S3 CSV file with syntax highlighting
  if ! command -v aws &> /dev/null; then
    echo "❌ aws-cli not installed. Run: brew install awscli"
    return 1
  fi
  if ! command -v bat &> /dev/null; then
    echo "❌ bat not installed. Run: brew install bat"
    return 1
  fi

  aws --profile=mgmt s3 cp "$1" - | bat -l csv
}

function s3json() {
  # View S3 JSON file with syntax highlighting
  if ! command -v aws &> /dev/null; then
    echo "❌ aws-cli not installed. Run: brew install awscli"
    return 1
  fi
  if ! command -v bat &> /dev/null; then
    echo "❌ bat not installed. Run: brew install bat"
    return 1
  fi

  aws --profile=mgmt s3 cp "$1" - | bat -l json
}


function shit() {
  # Fix last command using AI with aichat
  local last_exit=$?
  if ! command -v aichat &> /dev/null; then
    echo "❌ aichat not installed. Run: brew install aichat"
    return 1
  fi

  if ! command -v bat &> /dev/null; then
    echo "❌ bat not installed. Run: brew install bat"
    return 1
  fi

  if ! _load_env "OPENAI_API_KEY"; then
    echo "❌ Set OPENAI_API_KEY in $DOTFILES/.env"
    return 1
  fi

  if [ -n "$1" ]; then
    local prompt="$1"
  else
    local last_command=$(fc -ln -1 | sed 's/^[[:space:]]*//')

    if [ "$last_command" = "shit" ]; then
      echo "⚠️  Can't fix 'shit' itself. Run a command first."
      return 0
    fi

    local prompt="The following shell command failed with exit code $last_exit. Fix it and explain briefly what was wrong: $last_command"
  fi

  OPENAI_API_KEY="$OPENAI_API_KEY" aichat -r command-fixer "$prompt" | bat -l md
}

function ai() {
  # Ask general questions to AI with aichat
  if ! command -v aichat &> /dev/null; then
    echo "❌ aichat not installed. Run: brew install aichat"
    return 1
  fi

  if ! _load_env "OPENAI_API_KEY"; then
    echo "❌ Set OPENAI_API_KEY in $DOTFILES/.env"
    return 1
  fi

  OPENAI_API_KEY="$OPENAI_API_KEY" aichat -r general "$*"
}


function git-branch-clean() {
  # Delete local branches that have been merged to the default branch
  if ! command -v git &> /dev/null; then
    echo "❌ git not installed"
    return 1
  fi
  local default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  [[ -z "$default" ]] && default="main"
  local merged=$(git branch --merged="$default" | grep -v "$default" | grep -v '^\*')
  if [[ -z "$merged" ]]; then
    echo "No merged branches to clean."
    return 0
  fi
  echo "$merged" | xargs git branch -d
  git fetch --prune
}

function claude() {
  # Wrapper that loads .env before calling Claude Code (for MCP servers)
  if [ -f "$DOTFILES/.env" ]; then
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      export "$key=$value"
    done < "$DOTFILES/.env"
  fi
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
  EDITOR=nvim VISUAL=nvim /Users/andrew/.local/bin/claude "$@"
}

function droid() {
  # Wrapper that loads .env before calling Droid
  if [ -f "$DOTFILES/.env" ]; then
    while IFS='=' read -r key value; do
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      export "$key=$value"
    done < "$DOTFILES/.env"
  fi
  command droid "$@"
}

function pi() {
  # Wrapper that exports only OPENAI_API_KEY from .env before calling pi
  if [ -f "$DOTFILES/.env" ]; then
    local value=$(grep "^OPENAI_API_KEY=" "$DOTFILES/.env" | cut -d= -f2- | sed 's/^["'\'']//' | sed 's/["'\'']$//')
    [ -n "$value" ] && export OPENAI_API_KEY="$value"
  fi
  command pi "$@"
}

function cleanup-worktrees() {
  # Find and remove git worktrees across all projects
  local -a sizes paths repos

  while IFS= read -r gitdir; do
    local repo_git=$(dirname $(dirname "$gitdir"))
    local repo=$(dirname "$repo_git")
    local wt_name=$(basename $(dirname "$gitdir"))
    local actual=$(git -C "$repo" worktree list --porcelain 2>/dev/null | grep -A2 "$wt_name" | grep "worktree " | sed 's/worktree //')
    if [[ -n "$actual" ]] && [[ -d "$actual" ]]; then
      sizes+=($(du -sh "$actual" 2>/dev/null | cut -f1))
      paths+=("$actual")
      repos+=("$repo")
    fi
  done < <(find ~/code -name "gitdir" -path "*worktrees*" -maxdepth 8 2>/dev/null)

  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "No worktrees found."
    return 0
  fi

  echo "Git worktrees found:"
  echo "===================="
  for i in {1..${#paths[@]}}; do
    printf "  %d) %6s  %s\n" "$i" "${sizes[$i]}" "${paths[$i]}"
  done
  echo ""
  echo "Options: 'all' to remove all, numbers to pick (e.g. '1 3'), 'q' to quit"
  read "choice?> "

  [[ "$choice" == "q" ]] && return 0

  local -a indices
  if [[ "$choice" == "all" ]]; then
    indices=($(seq 1 ${#paths[@]}))
  else
    indices=(${=choice})
  fi

  for idx in "${indices[@]}"; do
    echo "Removing ${paths[$idx]}..."
    git -C "${repos[$idx]}" worktree remove "${paths[$idx]}" --force 2>/dev/null || rm -rf "${paths[$idx]}"
    git -C "${repos[$idx]}" worktree prune 2>/dev/null
  done
  echo "Done."
}

function spec-status() {
  # Show status of all specs across projects
  local md=()
  md+=("| Project | Spec | Status |")
  md+=("| --- | --- | --- |")
  local found=0
  for logbook in ~/.spec/*/*/logbook.md(N); do
    local spec=$(basename $(dirname "$logbook"))
    local project=$(basename $(dirname $(dirname "$logbook")))
    local status=$(grep -m1 "Status:" "$logbook" 2>/dev/null | sed 's/.*Status: *//')
    [[ -z "$status" ]] && status="UNKNOWN"
    md+=("| ${project} | ${spec} | ${status} |")
    found=1
  done

  if [[ $found -eq 0 ]]; then
    echo "No specs found."
    return 0
  fi

  if command -v gum &>/dev/null; then
    gum style --border rounded --border-foreground 99 --padding "0 1" --bold --foreground 212 " Spec Sessions"
    echo ""
    gum format -- "${md[@]}"
  else
    printf '%s\n' "${md[@]}"
  fi
}

function cleanup-docker() {
  # Show Docker disk usage and interactively prune resources
  if ! command -v docker &> /dev/null; then
    echo "❌ docker not installed"
    return 1
  fi
  if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker daemon is not running"
    return 1
  fi

  echo "Docker disk usage:"
  echo "=================="
  docker system df
  echo ""

  local images=$(docker images -q | wc -l | tr -d ' ')
  local containers=$(docker ps -aq | wc -l | tr -d ' ')
  local volumes=$(docker volume ls -q | wc -l | tr -d ' ')

  echo "Resources: $images images, $containers containers, $volumes volumes"
  echo ""
  echo "Options:"
  echo "  1) Prune unused (safe — keeps tagged images)"
  echo "  2) Prune ALL (removes everything not running)"
  echo "  3) Prune ALL + volumes (nuclear)"
  echo "  q) Quit"
  read "choice?> "

  case "$choice" in
    1) docker system prune -f ;;
    2) docker system prune -a -f ;;
    3) docker system prune -a --volumes -f ;;
    q) return 0 ;;
    *) echo "Invalid option" ;;
  esac

  echo ""
  echo "After cleanup:"
  docker system df
}
