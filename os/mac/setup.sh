defaults write com.apple.Dock autohide-time-modifier -float 0.15
defaults write com.apple.Dock autohide-delay -float 0
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.universalaccess reduceTransparency -bool true

# Disable Chinese translation shortcuts that conflict with Hyper key bindings
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '<dict><key>enabled</key><false/></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 '<dict><key>enabled</key><false/></dict>'
