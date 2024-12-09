#!/bin/zsh

source ./config

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

clear
echo Enter root password

# Ask for the administrator password upfront.
sudo -v

# Keep Sudo until script is finished
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

# Update macOS
echo
echo "${GREEN}Looking for updates.."
echo
sudo softwareupdate -i -a

# Install Rosetta
sudo softwareupdate --install-rosetta --agree-to-license

# Install Homebrew
echo
echo "${GREEN}Installing Homebrew"
echo
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Append Homebrew initialization to .zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>${HOME}/.zprofile
# Immediately evaluate the Homebrew environment settings for the current session
eval "$(/opt/homebrew/bin/brew shellenv)"

# Check installation and update
echo
echo "${GREEN}Checking installation.."
echo
brew update && brew doctor
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Check for Brewfile in the current directory and use it if present
if [ -f "./Brewfile" ]; then
  echo
  echo "${GREEN}Brewfile found. Using it to install packages..."
  brew bundle
  echo "${GREEN}Installation from Brewfile complete."
else
  # If no Brewfile is present, continue with the default installation

  # Install Casks and Formulae
  echo
  echo "${GREEN}Installing formulae..."
  for formula in "${FORMULAE[@]}"; do
    brew install "$formula"
    if [ $? -ne 0 ]; then
      echo "${RED}Failed to install $formula. Continuing...${NC}"
    fi
  done

  echo "${GREEN}Installing casks..."
  for cask in "${CASKS[@]}"; do
    brew install --cask "$cask"
    if [ $? -ne 0 ]; then
      echo "${RED}Failed to install $cask. Continuing...${NC}"
    fi
  done

  # App Store
  echo
  echo -n "${RED}Install apps from App Store? ${NC}[y/N]"
  read REPLY
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    brew install mas
    for app in "${APPSTORE[@]}"; do
      eval "mas install $app"
    done
  fi

  # VS Code Extensions
  echo
  echo -n "${RED}Install VSCode Extensions? ${NC}[y/N]"
  read REPLY
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Install VS Code extensions from config.sh file
    for extension in "${VSCODE[@]}"; do
      code --install-extension "$extension"
    done
  fi
fi

# Install NPM Packages
echo
echo "${GREEN}Installing Global NPM Packages..."
npm install -g ${NPMPACKAGES[@]}

# Optional Packages
echo
echo -n "${RED}Install .NET? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install dotnet
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
fi

echo
echo -n "${RED}Install Firefox Developer Edition? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew tap homebrew/cask-versions
  brew install firefox-developer-edition
fi

# Cleanup
echo
echo "${GREEN}Cleaning up..."
brew update && brew upgrade && brew cleanup && brew doctor
mkdir -p ~/Library/LaunchAgents
brew tap homebrew/autoupdate
brew autoupdate start $HOMEBREW_UPDATE_FREQUENCY --upgrade --cleanup --immediate --sudo

# Settings
echo
echo -n "${RED}Configure default system settings? ${NC}[Y/n]"
read REPLY
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
  echo "${GREEN}Configuring default settings..."
  for setting in "${SETTINGS[@]}"; do
    eval $setting
  done
fi

# Dock settings
echo
echo -n "${RED}Apply Dock settings?? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install dockutil
  # Handle replacements
  for item in "${DOCK_REPLACE[@]}"; do
    IFS="|" read -r add_app replace_app <<<"$item"
    dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
  done
  # Handle additions
  for app in "${DOCK_ADD[@]}"; do
    dockutil --add "$app" &>/dev/null
  done
  # Handle removals
  for app in "${DOCK_REMOVE[@]}"; do
    dockutil --remove "$app" &>/dev/null
  done
fi

# Git Login
echo
echo "${GREEN}SET UP GIT"
echo

echo "${RED}Please enter your git username:${NC}"
read name
echo "${RED}Please enter your git email:${NC}"
read email

git config --global user.name "$name"
git config --global user.email "$email"
git config --global color.ui true

echo
echo "${GREEN}GITTY UP!"

# ohmyzsh
echo
echo "${GREEN}Installing ohmyzsh!"
echo
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo
echo
printf "${RED}"
read -s -k $'?Press ANY KEY to REBOOT\n'
sudo reboot
exit
