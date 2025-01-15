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

notice() {
    echo -e "${GREY}$1${RESET}\n"
}

info() {
    echo -e "${BLUE}$1${RESET}\n"
}

warn() {
    echo -e "${YELLOW}$1${RESET}\n"
}

success() {
    echo -e "${GREEN}$1${RESET}\n"
}

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as sudo. Please re-run with sudo.${RESET}" 
   exit 1
fi

warn "Running with sudo privileges..."

# Notify on finish
warn "do you wanna get notifed on finish? [Y/n]"
read NOTFY_FINISH

NOTFY_FINISH=$(echo "$NOTFY_FINISH" | tr '[:upper:]' '[:lower:]')

if [ -z "$NOTFY_FINISH" ]; then
    NOTFY_FINISH="n"
fi

# Updates etc...
sudo apt update -y && sudo apt upgrade -y
success "successfully updated system"

# Install qemu-guest-agent
info "Setting up qemu-guest-agent\n"
sudo apt-get install qemu-guest-agent -y && sudo systemctl enable --now qemu-guest-agent
success "successfully installed and started the qemu-guest-agent"

# Install base packages
info "Setting up base packages (git, ufw...)\n"
sudo apt-get install git ufw
success "successfully installing base packages"

# Expose ssh port
info "Exposing ssh port 22"
sudo ufw enable && sudo ufw allow 22
success "successfully exposed port 22"

# Tailwcale
notice "Do you wanna setup tailscale [Y/N]: "
read TAILSCALE_SETUP

TAILSCALE_SETUP=$(echo "$TAILSCALE_SETUP" | tr '[:upper:]' '[:lower:]')

if [ -z "$TAILSCALE_SETUP" ]; then
    TAILSCALE_SETUP="n"
fi

if ["$TAILSCALE_SETUP" == "y"]; then
    info "Setting up tailscale"
    notice "provide tailscale auth key: " 
    read TS_AUTH_KEY

    curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --auth-key=$TS_AUTH_KEY
    TS_IP=$(tailscale ip | grep -E "^[0-9]+\.")
    success "successfully setup tailscale${RESET}${GREY} - ${TS_IP}"
elif ["$TAILSCALE_SETUP" == "n"]; then
    notice "not installing tailscale"
else
    notice "assuming default: no (tailscale)"
fi
# Setup docker
warn "do you wanna setup docker? [Y/n]"
read DOCKER_SETUP

DOCKER_SETUP=$(echo "$DOCKER_SETUP" | tr '[:upper:]' '[:lower:]')

if [ -z "$DOCKER_SETUP" ]; then
    DOCKER_SETUP="n"
fi

if [ "$DOCKER_SETUP" == "y" ]; then
    info "setting up docker"

    # Add Docker's official GPG key:
    notice "adding dockers offical GPG key..."
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    notice "adding apt sources..."
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    # Install docker
    notice "installing docker via APT..."
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    # Rootless docker
    notice "rootless docker setup..."
    sudo groupadd docker && sudo usermod -aG docker $USER && newgrp docker

    # Start on boot (just incase)
    notice "setting docker to start on boot (just incase)..."
    sudo systemctl enable docker && sudo systemctl enable containerd

    success "docker installed"
elif [ "$user_input" == "n" ]; then
    notice "not installing docker"
else
    notice "assuming default: no (docker)"
fi

# Setting up beszel monitoring
info "Setting up beszel monitoring agent"

notice "enter beszel monitoring ssh key: "
read BESZEL_SSH_KEY

curl -sL https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh -o install-agent.sh && chmod +x install-agent.sh && ./install-agent.sh -p 45876 -k "$BESZEL_SSH_KEY"
sudo ufw allow 45876
success "beszel setup - add it in the dashboard ${RESET}${GREY}\"$IP\" (https://monitor.banham.info)"


if [ "$NOTFY_FINISH" == "y" ]; then
    read -p "NTFY Username: " NTFY_USR
    read -p "NTFY Password: " NTFY_PWD

    curl -u "$NTFY_USR:$NTFY_PWD" -d "Service is finish setting up (rebooting next) - ${USERNAME} (LOCAL: ${IP}/TS: ${TS_IP})" ntfy.banham.info/system_notfy
fi

warn "\n\nrebooting..."
sudo reboot