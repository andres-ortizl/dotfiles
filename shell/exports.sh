# Exports based on architecture

# Common exports (needed before PATH setup)
export GOPATH="$HOME/.go"
export GEM_HOME="$HOME/.gem"
export LC_ALL='en_US.UTF-8'
export LANG='en_US.UTF-8'

# Fix for Ghostty terminal
if [[ "$TERM" == "xterm-ghostty" ]]; then
  export TERM=xterm-256color
fi

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  export JAVA_HOME='/Library/Java/JavaVirtualMachines/amazon-corretto-15.jdk/Contents/Home'
  export PIPX_HOME=~/.local/pipx
  export path=(
    "$HOME/.npm-global/bin"
    "/usr/local/opt/ruby/bin"
    "/usr/local/opt/python/libexec/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/bin"
    "/usr/bin"
    "/usr/sbin"
    "$HOME/.cargo/bin"
    "/opt/homebrew/opt/make/libexec/gnubin"
    "/opt/homebrew/opt/libpq/bin"
    "/opt/homebrew/opt/openjdk/bin"
    "/Users/andresortiz/.local/bin"
    "/Users/andrew/.local/bin"
    "/sbin"
  )
fi



# Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  export JAVA_HOME=/usr/lib/jvm/default
  export GTK_THEME=Catppuccin-Mocha-Standard-Mauve-Dark nautilus
  export path=(
    "$HOME/bin"
    "$HOME/.npm-global/bin"
    "$JAVA_HOME/bin"
    "$GEM_HOME/bin"
    "$GOPATH/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/bin"
    "$HOME/.cargo/bin"
    "/usr/bin"
    "/usr/sbin"
    "/sbin"
    "/home/andrew/.local/share/JetBrains/Toolbox/scripts"
    "$HOME/.bun/bin"
  )
fi

# Additional common exports
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

export "MICRO_TRUECOLOR=1"
export STARSHIP_CONFIG="$HOME/.config/starship/config.toml"
export BAT_CONFIG_PATH="$HOME/.config/bat/bat.conf"
