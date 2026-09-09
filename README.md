# 🎨 Dotfiles

![Workflow Status](https://github.com/andres-ortizl/dot-files/actions/workflows/tests.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Repo Size](https://img.shields.io/github/repo-size/andres-ortizl/dot-files)

A cross-platform dotfiles repository with automated setup using [dotbot](https://github.com/anishathalye/dotbot). Supports both **Arch Linux** and **macOS** with OS-specific configurations.

## 📸 Screenshots

### Hyprland (Arch Linux)

**Clean Desktop**
![Clean Desktop](data/screenshots/desktop-clean.png)
*Hyprland with Waybar, custom blur effects, and wallpaper*

**Terminal Setup**
![Terminal with system information](data/screenshots/terminal-neofetch.png)
*Ghostty terminal showing system information*

**System Monitor**
![Terminal with btop](data/screenshots/terminal-btop.png)
*btop system monitor in Ghostty terminal*

**Tiled Workspace**
![Tiled Windows](data/screenshots/workspace-tiled.png)
*Multiple windows tiled showing the power of Hyprland's window management*

**Spotify Scratchpad**
*Spicetify-themed Spotify scratchpad with Waybar media controls (SUPER+M).*

## 🎯 Philosophy

This dotfiles repository is built on a few core principles:

- **Cross-platform by design:** Single repository managing configurations across multiple operating systems, with OS-aware automation that adapts to your environment
- **Automation-first:** One command installation that handles everything—no manual symlink creation or configuration copying
- **Modular organization:** Configurations are organized by function and application, making it easy to understand, maintain, and extend
- **Version-controlled evolution:** All configuration changes are tracked in git, enabling experimentation with the safety of rollback
- **Symlink-based system:** Changes reflect immediately without manual copying—edit once, apply everywhere
- **Modern tooling:** Preference for modern, fast, and developer-friendly tools that enhance productivity
- **Developer-focused:** Optimized for software development workflows with sensible defaults and powerful shortcuts

## 🏗️ Architecture

The repository uses a modular, OS-aware architecture that automatically configures your system based on the detected operating system.

### Core Structure

```
dotfiles/
├── config/          # Application configurations (organized by app)
├── shell/           # Shell environment (aliases, functions, exports)
├── modules/         # Git submodules (dotbot installation framework)
├── bin/             # Custom executables and scripts
├── os/              # OS-specific configurations and setup scripts
├── language/        # Programming language-specific configurations
├── data/            # Assets (screenshots, wallpapers, themes)
├── .arch-conf.yml   # Arch Linux dotbot configuration
├── .mac-conf.yml    # macOS dotbot configuration
└── install          # Automated installation script
```

### How It Works

1. **Installation:** Run `./install` to automatically detect your OS and create symlinks
2. **Symlink Creation:** Dotbot creates symlinks from the repository to your home directory
3. **Shell Integration:** The installer sets up `$DOTFILES` environment variable and sources shell configurations
4. **Immediate Effect:** Changes to dotfiles are immediately reflected in your system

## 🚀 Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/andres-ortizl/dot-files.git ~/code/dotfiles
cd ~/code/dotfiles

# Run installer (auto-detects OS)
./install

# Or specify config manually
./install -c .arch-conf.yml  # For Arch Linux
./install -c .mac-conf.yml   # For macOS
```

The installer will:
1. Initialize git submodules (dotbot)
2. Detect your operating system
3. Create symlinks based on OS-specific config
4. Set up shell environment
5. Configure `$DOTFILES` environment variable

### What Gets Installed

**Common (Both OS):**
- Shell configurations (Zsh with Zim framework)
- Git configuration
- Modern CLI tools (Starship, Bat, Eza, Fastfetch, and Yazi)
- Terminal emulator (Ghostty)
- Code editor (Zed)

**Arch Linux Specific:**
- Hyprland window manager (Wayland compositor)
- Waybar status bar
- Spotify Launcher with Spicetify, Marketplace, and Catppuccin styling
- Vicinae application launcher
- Dunst notifications
- Wlogout power menu
- Zen Browser
- Thunar file manager
- Awww wallpaper manager with Matugen-generated accents
- Satty screenshot annotation and Hyprpicker color selection
- Hyprsunset blue-light filtering

**macOS Specific:**
- Karabiner keyboard customization
- iTerm2 configuration
- Amethyst window manager
- GitKraken themes

## 📁 Directory Structure

### `config/`
Application-specific configurations organized by tool. Each application has its own subdirectory with all related configuration files. Examples include:
- `hypr/` - Hyprland window manager (modular config files)
- `waybar/` - Status bar with custom modules
- `ghostty/` - Terminal emulator configuration
- `zed/` - Code editor settings
- `git/` - Git aliases and configuration
- `starship/` - Cross-shell prompt configuration
- And many more...

### `shell/`
Shell environment configuration that's automatically sourced:
- `main.sh` - Entry point that sources all other files
- `aliases.sh` - Command aliases (git shortcuts, modern tool replacements)
- `exports.sh` - Environment variables and PATH configuration
- `functions.sh` - Custom shell functions for common tasks
- `functions/` - Executable shell scripts added to PATH

**Key features:**
- Git workflow shortcuts (`gl`, `gaa`, `gco`, `gs`, etc.)
- Modern command replacements (`ls` → `eza`, `cat` → `bat`, `vim` → `nvim`)
- Custom functions for Docker, Kubernetes, AWS, and more
- Automatic `$DOTFILES` environment variable

### `os/`
OS-specific configurations and setup scripts:
- `archlinux/` - Arch Linux specific setup and hooks
- `mac/` - macOS specific configurations
- `homeserver/` - Server-specific configurations

### `language/`
Programming language-specific configurations for Go, Java, Python, Rust, etc.

### `modules/`
Git submodules for external dependencies (currently just dotbot).

### `bin/`
Custom executables and scripts that should be in `$PATH`.

### `data/`
Non-configuration files like screenshots, wallpapers, and themes.

## ⚙️ Configuration Philosophy

### Modular Configuration
Complex configurations are broken into logical modules. For example, Hyprland configuration is split across multiple files:
- `monitor.conf` - Display setup
- `keybinding.conf` - All keybindings
- `decoration.conf` - Visual effects
- `windowrule.conf` - Per-application rules
- And more...

This makes it easy to understand, modify, and maintain large configurations.

### OS-Aware Configuration
The dotbot configuration files (`.arch-conf.yml`, `.mac-conf.yml`) define OS-specific symlink mappings. Some applications have OS-specific configs:
- Shell RC files (`.zshrc_arch` vs `.zshrc_mac`)
- Application configs (different paths for macOS vs Linux)
- Tool-specific settings that vary by platform

### Shell Integration
The installer automatically adds to your shell RC files:
```bash
export DOTFILES=/path/to/dotfiles
source $DOTFILES/shell/main.sh
```

This loads all aliases, functions, and exports automatically on every shell session.

## 🎯 Current Setup

### Arch Linux (Hyprland)
A modern Wayland-based desktop environment:
- **Window Manager:** Hyprland (Wayland compositor)
- **Status Bar:** Waybar with custom modules
- **Music:** Spotify scratchpad with Spicetify and Waybar MPRIS controls
- **Terminal:** Ghostty
- **Shell:** Zsh with Zim framework
- **Editor:** Zed, Neovim
- **Launcher:** Vicinae
- **Browser:** Zen Browser
- **File Manager:** Thunar
- **Notifications:** Dunst
- **Lock Screen:** Hyprlock
- **Wallpaper:** Awww with a Quickshell picker
- **Theme:** Catppuccin Mocha with wallpaper-derived Matugen accents

### macOS
A consistent development environment:
- **Window Manager:** Amethyst
- **Terminal:** Ghostty, iTerm2
- **Shell:** Zsh with Zim framework
- **Editor:** Zed, Neovim
- **Keyboard:** Karabiner-Elements for customization
- **Theme:** Consistent with Linux setup

## 🔧 Customization

### Adding New Applications

1. Add configuration files to `config/your-app/`
2. Add symlink mapping to the appropriate dotbot config file (`.arch-conf.yml` or `.mac-conf.yml`):
   ```yaml
   - link:
       ~/.config/your-app: config/your-app/**
   ```
3. Run `./install` to create symlinks

### Modifying Shell Configuration

Edit files in `shell/` directory:
- `aliases.sh` - Add new aliases
- `functions.sh` - Add new functions
- `exports.sh` - Add environment variables

Changes take effect immediately (no reinstall needed) after reloading your shell.

### OS-Specific Customization

Some apps have OS-specific configs. Check the dotbot configuration files to see how OS-specific paths are handled. You can add new OS-specific configurations by:
1. Creating OS-specific config files (e.g., `config_linux.json` vs `config_mac.json`)
2. Mapping them appropriately in the dotbot config files

## 📦 Dependencies

### Arch Linux
```bash
# Layered manifests live under os/archlinux/packages/
# `legacy.list` is archival; use the first three for normal installs.
# Example installs:
paru -S --needed - < os/archlinux/packages/base.list
paru -S --needed - < os/archlinux/packages/hypr-desktop.list
paru -S --needed - < os/archlinux/packages/optional.list
```

### macOS
```bash
# Using Homebrew
brew install zsh git neovim eza bat fastfetch starship yazi
brew install ghostty zed
brew install --cask amethyst karabiner-elements
```

## 🛠️ Management

### Update Dotfiles
```bash
cd ~/code/dotfiles
git pull
./install  # Recreate symlinks if needed
```

### Update Submodules
```bash
git submodule update --remote --merge
```

### Check Symlink Status
```bash
# See where configs are linked
ls -la ~/.config/ | grep " -> "
```

### Uninstall
```bash
# Dotbot clean (removes dead symlinks)
./install -c .arch-conf.yml --only clean
```

## 🧩 Notable Features

### Hyprland Configuration
Modular Lua configuration with fullscreen-only VRR, Hyprsunset scheduling, and focused screenshot and color tools.

### Dynamic Desktop Theme
Wallpaper changes preserve the Catppuccin base palette while Matugen updates accents in Quickshell, Waybar, Dunst, Ghostty, and Hyprland.

### Spotify Rice
Spotify Launcher runs as a `SUPER+M` scratchpad. The cold-launch wrapper checks for client updates, reapplies the Sleek Catppuccin theme and Marketplace, and then starts Spotify. A separate Waybar media island provides track metadata plus previous, play/pause, and next controls. The first launch is unthemed so Spotify can create its preferences file. Close and reopen it once to apply Spicetify.

### Audio Routing
The Waybar volume module opens a Quickshell output panel with global volume, mute, and one-click device switching. Selecting an output moves active media streams to it. Discord remains pinned to the HyperX headset. The advanced mixer remains available from the panel and from right-clicking the Waybar volume module.

### Pi Beacon
The `pi-beacon` uv tool and Pi extension publish live main-session state, consume pi-subagents lifecycle artifacts, and index daily usage incrementally with SQLModel. Waybar shows the compact `πⁿ` status; clicking opens the themed Quickshell dashboard. Use `Ctrl+Alt+F` inside Pi for the full FleetView.

### Night Shift
Hyprsunset follows the automatic 19:00 to 06:00 schedule. The Waybar control can force warm or off modes, restore the automatic schedule with right-click, and adjust warmth with the scroll wheel. Fullscreen windows temporarily suspend the filter.

### Shell Enhancements
- Modern CLI tool replacements (Eza, Bat, and others)
- Comprehensive git workflow shortcuts
- Custom functions for Docker, Kubernetes, AWS workflows
- Fuzzy finder integration (fzf) for history, processes, and more

### Custom Scripts
- `config/hypr/scripts/` - Hyprland utility scripts (screenshots, scratchpads)
- `config/waybar/scripts/` - Custom Waybar modules
- `config/keybindings-helper/` - TUI keybinding viewer

## OpenClaw on the homeserver

OpenClaw is an optional personal knowledge assistant alongside Open WebUI. It uses OpenAI for generation and embeddings, built-in hybrid memory, Memory Wiki, and the pinned WhatsApp plugin. The `knowledge-capture` skill adapts Hippo's capture and source-preservation rules. It has no shell tools, NAS administration, email access, or automatic schedules. Heartbeat and dreaming are disabled until a cadence and API budget are chosen.

Configuration and instructions live in `os/homeserver/config/openclaw/`. Personal data, WhatsApp credentials, and installed plugins live under the ignored `os/homeserver/data/openclaw/`. The existing Backrest `/userdata` mount includes this directory; verify the configured backup plan covers it before relying on recovery. Raw captures are preserved by workflow convention, not filesystem write protection.

### Initial setup

Run these steps on the NAS after committing the configuration. `PUID` and `PGID` in the homeserver `.env` must match the deployment user's `id -u` and `id -g`, so the container can write its state. Docker Compose 2.24 or newer is required for the optional env file.

1. Add an `openclaw.env` attachment to the existing `n33lab-homeserver-runtime` Bitwarden item. It must contain exactly `OPENAI_API_KEY`, `OPENCLAW_GATEWAY_TOKEN`, and `OPENCLAW_OWNER_PHONE`. Generate a token with `openssl rand -hex 32`. Use the owner's E.164 phone number as the permitted sender. Do not put these values in Git.
2. Restore secrets and prepare private storage:

   ```bash
   cd os/homeserver
   ./recover-env.sh --openclaw
   install -d -m 700 data/openclaw data/openclaw/workspace
   ```

3. Install the pinned WhatsApp plugin using a temporary writable setup config. The runtime config remains read-only:

   ```bash
   docker compose run --rm --no-deps \
     -e OPENCLAW_CONFIG_PATH=/tmp/openclaw-setup/openclaw.json \
     openclaw node dist/index.js plugins install npm:@openclaw/whatsapp@2026.9.2
   docker compose run --rm --no-deps openclaw node dist/index.js config validate
   docker compose run --rm --no-deps openclaw node dist/index.js wiki init
   ```

4. Pair the assistant's WhatsApp account using the live QR in your terminal. Login material is sensitive; do not post it to logs or chats. The integration uses WhatsApp Web through Baileys, not the Business API:

   ```bash
   docker compose run --rm --no-deps openclaw node dist/index.js channels login --channel whatsapp
   ./deploy.sh openclaw
   docker compose exec openclaw node dist/index.js security audit
   ```

The gateway publishes only `127.0.0.1:18789` on the NAS, with token authentication. There is no Traefik/public route. Over your existing Tailscale access to the NAS, use `ssh -N -L 18789:127.0.0.1:18789 andrew@192.168.1.33`, then open `http://127.0.0.1:18789` locally and approve browser pairing from the CLI if requested. Do not disable gateway authentication or device pairing. The separate Docker network reduces direct container access but is not an outbound LAN firewall.

The first deployment uses `deploy.sh` because the image-lock workflow requires an already running container. After bootstrap, use `scripts/manage.sh` for operational changes.

Keep `COMPOSE_PROFILES` unset for ordinary stack operations. Use `COMPOSE_PROFILES=openclaw` with `scripts/manage.sh` when managing this service. Read-only config changes require a container restart; image and plugin upgrades remain explicit and version-pinned. Follow `os/homeserver/UPDATE_IMAGES.md` for image changes.

### Validation

From the repository root, pull the exact image pinned in Compose, then run `python3 -m unittest discover -s os/homeserver/tests -v`. The tests install the pinned WhatsApp plugin in temporary storage. All subsequent container commands have networking disabled and use dummy credentials. They validate the real OpenClaw schema, gateway health/authentication, read-only instructions, and source-backed wiki/keyword retrieval across container restarts. They do not test model quality, live WhatsApp delivery, or real secret recovery.

## 🐛 Troubleshooting

### Symlinks Not Created
```bash
# Check dotbot output
./install -v  # Verbose mode

# Manually verify symlinks
ls -la ~/.config/your-app
```

### Shell Changes Not Applied
```bash
# Reload shell
source ~/.zshrc

# Or verify $DOTFILES is set
echo $DOTFILES
```

### OS Detection Issues
```bash
# Check detected OS
uname -s  # Darwin (macOS) or Linux

# Force specific config
./install -c .arch-conf.yml
```

### Submodule Problems
```bash
# Reset submodules
git submodule deinit -f .
git submodule update --init --recursive
```

## 📚 Documentation

- [Dotbot](https://github.com/anishathalye/dotbot) - Installation framework
- [Hyprland Wiki](https://wiki.hyprland.org/) - Wayland compositor
- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki) - Status bar
- [Zim Framework](https://github.com/zimfw/zimfw) - Zsh plugin manager

## 🔄 Continuous Integration

GitHub Actions run for pushes and pull requests. The workflow:
- Validates JSON, TOML, YAML, shell scripts, and available desktop configs
- Tests Dotbot installation on current Ubuntu and macOS runners
- Runs the Soloist TUI and Specdex Rust test suites with locked dependencies

This repository has no automatic deployment target. Run `./install` explicitly to deploy the dotfiles on a workstation.

## 🤝 Contributing

Feel free to:
- Fork and customize for your own use
- Submit issues for bugs
- Suggest improvements

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 📫 Contact

For questions or suggestions: andres.ortiz.xyz@gmail.com
