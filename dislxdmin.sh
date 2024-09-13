#!/bin/bash

# Function to check if the script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Use sudo to run it."
        exit 1
    fi
}

echo -e '
########################################################################
# /$$$$$$$                                           /$$$$$$   /$$$$$$\#
#| $$__  $$                                         /$$__  $$ /$$__  $$#
#| $$  \ $$  /$$$$$$  /$$$$$$$  /$$$$$$$  /$$   /$$| $$  \ $$| $$  \ $$#
#| $$$$$$$  /$$__  $$| $$__  $$| $$__  $$| $$  | $$|  $$$$$$/|  $$$$$$/#
#| $$__  $$| $$$$$$$$| $$  \ $$| $$  \ $$| $$  | $$  $$__  $$  $$__  $$#
#| $$  \ $$| $$_____/| $$  | $$| $$  | $$| $$  | $$| $$  \ $$| $$  \ $$#
#| $$$$$$$/|  $$$$$$$| $$  | $$| $$  | $$|  $$$$$$$|  $$$$$$/|  $$$$$$/#
#|_______/  \_______/|__/  |__/|__/  |__/ \____  $$ \______/  \______/ #
#                                         /$$  | $$/                   #
#                                        |  $$$$$$/                    #
#                                         \______/                     #
########################################################################
########################################################################
#                      Welcome to Bennys scripting...                  #
#            Initiating the sequences and preparing disto...           #
########################################################################'
 sleep 1

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro=$ID
    else
        echo "Cannot detect the distribution. Exiting."
        exit 1
    fi
}

# Function to update and upgrade packages for Debian/Ubuntu
update_debian_ubuntu() {
    echo "Detected Debian/Ubuntu. Updating and upgrading packages..."
    apt update && apt upgrade -y
}

# Function to update and upgrade packages for Arch
update_arch() {
    echo "Detected Arch Linux. Updating and upgrading packages..."
    pacman -Syu --noconfirm
}

# Function to update and upgrade packages for Fedora
update_fedora() {
    echo "Detected Fedora. Updating and upgrading packages..."
    dnf upgrade --refresh -y
}

# Function to update and upgrade packages for Alpine
update_alpine() {
    echo "Detected Alpine Linux. Updating and upgrading packages..."
    apk update && apk upgrade
}

# Function to update and upgrade packages for AlmaLinux/RockyLinux (uses the same package manager as CentOS/Fedora)
update_alma_rocky() {
    echo "Detected AlmaLinux/Rocky Linux. Updating and upgrading packages..."
    dnf upgrade --refresh -y
}

# Function to install packages for Debian/Ubuntu
install_debian_ubuntu() {
    echo "Installing packages on Debian/Ubuntu..."
    apt install -y curl wget software-properties-common net-tools nmap htop fontconfig zip unzip bash-completion dconf-cli nano tmux python3 python3-psutil
}

# Function to install packages for Arch
install_arch() {
    echo "Installing packages on Arch Linux..."
    pacman -S --noconfirm curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 python-psutil
}

# Function to install packages for Fedora
install_fedora() {
    echo "Installing packages on Fedora..."
    dnf install -y curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 python3-psutil
}

# Function to install packages for Alpine
install_alpine() {
    echo "Installing packages on Alpine Linux..."
    apk add curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 py3-psutil
}

# Function to install packages for AlmaLinux/Rocky Linux
install_alma_rocky() {
    echo "Installing packages on AlmaLinux/Rocky Linux..."
    dnf install -y curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 python3-psutil
}

# Function to prompt for restart
prompt_restart() {
    read -p "Do you want to restart the system now? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Restarting the system..."
        reboot
    else
        echo "Restart skipped. You can restart manually later."
    fi
}

# Main script execution
check_root
detect_distro

case $distro in
    debian|ubuntu)
        update_debian_ubuntu
        install_debian_ubuntu
        ;;
    arch)
        update_arch
        install_arch
        ;;
    fedora)
        update_fedora
        install_fedora
        ;;
    alpine)
        update_alpine
        install_alpine
        ;;
    almalinux|rocky)
        update_alma_rocky
        install_alma_rocky
        ;;
    *)
        echo "Unsupported distribution: $distro. Exiting."
        exit 1
        ;;
esac

# Prompt for system restart
prompt_restart
