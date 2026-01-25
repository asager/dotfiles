#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "skip: not macOS"
  exit 0
fi

echo "Applying macOS defaults..."

# Key repeat / press-and-hold
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15
defaults write -g ApplePressAndHoldEnabled -bool false

# Typing corrections
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false

# Keep smart quotes/dashes enabled (matches current machine config)
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool true
defaults write -g NSAutomaticDashSubstitutionEnabled -bool true

# Trackpad speed
defaults write -g com.apple.trackpad.scaling -float 1

# Dock appearance
defaults write com.apple.dock tilesize -int 16
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock orientation -string bottom

# Finder default view style (Nlsv = list view)
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv

# Restart affected services
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "done"
