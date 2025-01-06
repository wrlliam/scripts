#!/bin/bash

# WIP

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"
GREY="\033[90m"
HOSTNAME=hostname
IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
USERHOST="$(whoami)@$(hostname)"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as sudo. Please re-run with sudo.${RESET}" 
   exit 1
fi

echo -e "${GREY}Running with sudo privileges...\n${RESET}"

# Notify on finish
echo -e "${YELLOW}do you wanna get notifed on finish? [Y/n]${RESET}"
read NOTFY_FINISH

NOTFY_FINISH=$(echo "$NOTFY_FINISH" | tr '[:upper:]' '[:lower:]')

if [ -z "$NOTFY_FINISH" ]; then
    NOTFY_FINISH="n"
fi

# Updates etc...
sudo apt update -y && sudo apt upgrade -y
echo -e "${GREEN}successfully updated system\n${RESET}"

# Install qemu-guest-agent
echo -e "${BLUE}Setting up qemu-guest-agent\n\n${RESET}"
sudo apt-get install qemu-guest-agent -y && sudo systemctl enable --now qemu-guest-agent
echo -e "${GREEN}successfully installed and started the qemu-guest-agent\n${RESET}"

# Install base packages
echo -e "${BLUE}Setting up base packages (git, ufw...)\n\n${RESET}"
sudo apt-get install git ufw
echo -e "${GREEN}successfully installing base packages\n${RESET}"

# Expose ssh port
echo -e "${BLUE}Exposing ssh port 22\n\n${RESET}"
sudo ufw enable && sudo ufw allow 22
echo -e "${GREEN}successfully exposed port 22\n${RESET}"

# Tailwcale
echo -e "${BLUE}Setting up tailscale\n\n${RESET}"
echo -e "${GREY}provide tailscale auth key: ${RESET}" 
read TS_AUTH_KEY

curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --auth-key=$TS_AUTH_KEY
TS_IP=$(tailscale ip | grep -E "^[0-9]+\.")
echo -e "${GREEN}successfully setup tailscale${RESET}${GREY} - ${TS_IP}\n${RESET}"

# Setup docker
echo -e "${YELLOW}do you wanna setup docker? [Y/n]${RESET}"
read DOCKER_SETUP

DOCKER_SETUP=$(echo "$DOCKER_SETUP" | tr '[:upper:]' '[:lower:]')

if [ -z "$DOCKER_SETUP" ]; then
    DOCKER_SETUP="n"
fi

if [ "$DOCKER_SETUP" == "y" ]; then
    echo -e "${BLUE}Setting up docker\n\n${RESET}"

    # Add Docker's official GPG key:
    echo -e "${GREY}adding dockers offical GPG key...${RESET}"
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo -e "${GREY}adding apt sources...${RESET}"
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    # Install docker
    echo -e "${GREY}installing docker via APT...${RESET}"
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    # Rootless docker
    echo -e "${GREY}rootless docker setup...${RESET}"
    sudo groupadd docker && sudo usermod -aG docker $USER && newgrp docker

    # Start on boot (just incase)
    echo -e "${GREY}setting up docker start on boot (just incase)...\n${RESET}"
    sudo systemctl enable docker && sudo systemctl enable containerd

    echo -e "${GREEN}docker installed\n\n${RESET}"
elif [ "$user_input" == "n" ]; then
    echo -e "${GREY}not installing docker${RESET}"
else
    echo -e "${GREY}assuming default: no${RESET}"
fi

# Setting up beszel monitoring
echo -e "${BLUE}Setting up beszel monitoring agent\n\n${RESET}"

echo -e "${GREY}enter beszel monitoring ssh key: ${RESET}"
read BESZEL_SSH_KEY

curl -sL https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh -o install-agent.sh && chmod +x install-agent.sh && ./install-agent.sh -p 45876 -k "$BESZEL_SSH_KEY"
sudo ufw allow 45876
echo -e "${GREEN}beszel setup - add it in the dashboard ${RESET}${GREY}(https://monitor.banham.info)\n\n${RESET}"


if [ "$NOTFY_FINISH" == "y" ]; then
    read -p "NTFY Username: " NTFY_USR
    read -p "NTFY Password: " NTFY_PWD

    curl -u "$NTFY_USR:$NTFY_PWD" -d "Service is finish setting up - ${USERNAME} (LOCAL: ${IP}/TS: ${TS_IP})\n\nRebooting" ntfy.banham.info/system_notfy
fi

echo -e "\n\n\n${YELLOW}rebooting...\n${RESET}"
sudo reboot