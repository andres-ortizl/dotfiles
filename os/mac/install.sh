# Download HomeBrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Restore packages from Brewfile
brew bundle --file="$MYPYDOTFILES/os/mac/Brewfile" --force cleanup

# Setting defaults for mac
$MYPYDOTFILES/os/mac/defaults.sh