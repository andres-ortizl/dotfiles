# Exports based on architecture

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  export JAVA_HOME='/Library/Java/JavaVirtualMachines/amazon-corretto-15.jdk/Contents/Home'
  export GEM_HOME="$HOME/.gem"
  export path=(
    "/usr/local/opt/ruby/bin"
    "/usr/local/opt/python/libexec/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/bin"
    "/usr/bin"
    "/usr/sbin"
    "/sbin"
  )
fi

# Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  export JAVA_HOME=/usr/lib/jvm/default
  export GTK_THEME=Catppuccin-Mocha-Standard-Mauve-Dark nautilus
  export path=(
    "$HOME/bin"
    "$JAVA_HOME/bin"
    "$GEM_HOME/bin"
    "$GOPATH/bin"
    "$HOME/.cargo/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/bin"
    "/usr/bin"
    "/usr/sbin"
    "/sbin"
    "/home/andrew/.local/share/JetBrains/Toolbox/scripts"
  )
fi

# Common
export GOPATH="$HOME/.go"
export LC_ALL='en_US.UTF-8'
export LANG='en_US.UTF-8'
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

export "MICRO_TRUECOLOR=1"
export STARSHIP_CONFIG="$HOME/.config/starship/config.toml"
