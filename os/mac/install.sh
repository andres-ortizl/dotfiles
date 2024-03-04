# Download HomeBrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Restore packages from Brewfile
brew bundle --file="$DOTFILES/os/mac/Brewfile" --force cleanup

# Setting defaults for mac
$DOTFILES/os/mac/defaults.sh

# export brew
brew bundle dump