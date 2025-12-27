# Debug Toolbox - Container for debugging other containers
# Shares namespaces (PID, NET, volumes) with target container
FROM ubuntu:24.04

ARG DOTFILES
LABEL org.opencontainers.image.source="${DOTFILES}/config/docker/debug-toolbox/Dockerfile"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color \
    ZIM_HOME=/root/.zim

# Install base packages and dependencies
RUN apt-get update && apt-get install -y \
    # Core utils
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    locales \
    # Shell
    zsh \
    # Process & system debugging
    procps \
    htop \
    btop \
    strace \
    lsof \
    psmisc \
    # Network debugging
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    tcpdump \
    nmap \
    netcat-openbsd \
    traceroute \
    mtr-tiny \
    # File system
    tree \
    file \
    rsync \
    # Build essentials (for some tools)
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Setup locale
RUN locale-gen en_US.UTF-8

# Install modern CLI tools from external sources
RUN apt-get update && apt-get install -y software-properties-common && \
    # Install bat (from apt - newer Ubuntu has it)
    apt-get install -y bat && ln -s /usr/bin/batcat /usr/local/bin/bat || true && \
    # Install fd-find
    apt-get install -y fd-find && ln -s /usr/bin/fdfind /usr/local/bin/fd || true && \
    # Install ripgrep
    apt-get install -y ripgrep && \
    # Install fzf
    apt-get install -y fzf && \
    rm -rf /var/lib/apt/lists/*

# Install eza (ls replacement) - detect architecture
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        EZA_ARCH="x86_64-unknown-linux-gnu"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        EZA_ARCH="aarch64-unknown-linux-gnu"; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    wget -qO- https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz | \
    tar xz -C /usr/local/bin

# Install micro editor
RUN curl -sL https://getmic.ro | bash && mv micro /usr/local/bin/ && \
    mkdir -p /root/.config/micro && \
    echo '{"colorscheme": "monokai", "syntax": true, "tabsize": 4, "tabstospaces": true, "autoindent": true, "ruler": true, "statusline": true}' > /root/.config/micro/settings.json

# Note: Fresh editor doesn't have arm64 binaries yet
# TODO: Add Fresh when arm64 support is available

# Install jq & yq
RUN apt-get update && apt-get install -y jq && \
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq && \
    rm -rf /var/lib/apt/lists/*

# Install httpie
RUN apt-get update && apt-get install -y python3-pip && \
    pip3 install --no-cache-dir httpie --break-system-packages && \
    rm -rf /var/lib/apt/lists/*

# Install usql (universal SQL client) via Go
RUN apt-get update && apt-get install -y golang-go && \
    go install github.com/xo/usql@latest && \
    mv /root/go/bin/usql /usr/local/bin/ && \
    apt-get remove -y golang-go && \
    apt-get autoremove -y && \
    rm -rf /root/go /var/lib/apt/lists/*

# Install starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# Note: Skipping procs - requires newer Rust than available in Ubuntu 24.04 repos
# Use standard 'ps' or 'htop' instead

# Install lazydocker
RUN curl -sL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Install kubectl (for k8s debugging if needed)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Setup minimal zsh config with starship
RUN mkdir -p /root/.config && \
    echo 'eval "$(starship init zsh)"' >> /root/.zshrc && \
    echo 'HISTFILE=~/.zsh_history' >> /root/.zshrc && \
    echo 'HISTSIZE=10000' >> /root/.zshrc && \
    echo 'SAVEHIST=10000' >> /root/.zshrc && \
    echo 'setopt HIST_IGNORE_ALL_DUPS' >> /root/.zshrc && \
    echo 'setopt SHARE_HISTORY' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Editor configuration' >> /root/.zshrc && \
    echo 'export EDITOR=micro' >> /root/.zshrc && \
    echo 'export VISUAL=micro' >> /root/.zshrc && \
    echo 'alias nano=micro' >> /root/.zshrc && \
    echo 'alias vim=micro' >> /root/.zshrc && \
    echo 'alias vi=micro' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Helpful aliases' >> /root/.zshrc && \
    echo 'alias target="cd /proc/1/root"' >> /root/.zshrc && \
    echo 'alias ls="eza"' >> /root/.zshrc && \
    echo 'alias ll="eza -la"' >> /root/.zshrc && \
    echo 'alias tree="eza --tree"' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Welcome message' >> /root/.zshrc && \
    echo 'echo "🔧 Debug Toolbox Ready"' >> /root/.zshrc && \
    echo 'echo "📦 Shared namespaces: PID, NET, Volumes"' >> /root/.zshrc && \
    echo 'echo ""' >> /root/.zshrc && \
    echo 'echo "Quick commands:"' >> /root/.zshrc && \
    echo 'echo "  target           - cd to target container filesystem"' >> /root/.zshrc && \
    echo 'echo "  ps aux           - all processes"' >> /root/.zshrc && \
    echo 'echo "  ss -tulpn        - listening sockets"' >> /root/.zshrc && \
    echo 'echo "  lsof             - open files"' >> /root/.zshrc && \
    echo 'echo "  tcpdump -i any   - network traffic"' >> /root/.zshrc && \
    echo 'echo "  micro/vim/vi     - text editor with syntax highlighting"' >> /root/.zshrc && \
    echo 'echo ""' >> /root/.zshrc

# Configure starship with jetpack theme
RUN starship preset jetpack -o ~/.config/starship.toml

# Set zsh as default shell
ENV SHELL=/usr/bin/zsh

WORKDIR /debug

# Default command: start zsh
CMD ["/usr/bin/zsh"]
