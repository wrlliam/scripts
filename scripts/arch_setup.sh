#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"
GREY="\033[90m"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as sudo. Please re-run with sudo." 
   exit 1
fi

echo -e "${GREY}Running with sudo privileges...\n"
PREVIOUS_PWD=$(pwd)

# # Install base packages
# echo -e "${BLUE}INFO:${RESET} Installing base packages (btop, neovim....)"
# sudo pacman -S btop neovim


# # Installing yay
# echo "Installing yay (https://github.com/Jguer/yay)...."
# sudo pacman -S --needed git base-devel
# mkdir -p ~/tmp
# cd ~/tmp
# git clone https://aur.archlinux.org/yay.git
# cd yay
# makepkg -si
# cd ../
# sudo rm -r yay

# cd $PREVIOUS_PWD


echo -e "${GREEN}Finished install script ${GREY}(arch)"