export JAVA_HOME='/Library/Java/JavaVirtualMachines/amazon-corretto-15.jdk/Contents/Home'
export GEM_HOME="$HOME/.gem"
export GOPATH="$HOME/.go"
export LC_ALL='en_US.UTF-8'
export LANG='en_US.UTF-8'
export STARSHIP_CONFIG="$HOME/.config/starship/config.toml"
export FZF_DEFAULT_OPTS='
  --color=pointer:#ebdbb2,bg+:#3c3836,fg:#ebdbb2,fg+:#fbf1c7,hl:#8ec07c,info:#928374,header:#fb4934
  --reverse
'
export "MICRO_TRUECOLOR=1"
export path=(
  "$HOME/bin"
  "$JAVA_HOME/bin"
  "$GEM_HOME/bin"
  "$GOPATH/bin"
  "$HOME/.cargo/bin"
  "/usr/local/opt/ruby/bin"
  "/usr/local/opt/python/libexec/bin"
  "/usr/local/bin"
  "/usr/local/sbin"
  "/bin"
  "/usr/bin"
  "/usr/sbin"
  "/opt/homebrew/bin"
  "/sbin"
  "/home/andrew/.local/share/JetBrains/Toolbox/scripts"
  "/usr/local/opt/kubernetes-cli@1.22/bin"
)
