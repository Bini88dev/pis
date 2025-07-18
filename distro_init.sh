#!/bin/bash

# Function to check if the script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root. Use sudo to run it."
        exit 1
    fi
}

# Colors for deloa
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Show deloa
echo -e "${GREEN}"
cat << "EOF"
██████╗ ███████╗███╗   ██╗███╗   ██╗██╗   ██╗ █████╗  █████╗
██╔══██╗██╔════╝████╗  ██║████╗  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗
██████╔╝█████╗  ██╔██╗ ██║██╔██╗ ██║ ╚████╔╝ ╚█████╔╝╚█████╔╝
██╔══██╗██╔══╝  ██║╚██╗██║██║╚██╗██║  ╚██╔╝  ██╔══██╗██╔══██╗
██████╔╝███████╗██║ ╚████║██║ ╚████║   ██║   ╚█████╔╝╚█████╔╝
╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═══╝   ╚═╝    ╚════╝  ╚════╝
                Welcome to Bennys scripting...
      Initiating the sequences and preparing disto...
EOF
echo -e "${NC}"
sleep 1s

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

# Retry function to handle package installations
install_with_retry() {
    local install_cmd="$1"
    local package="$2"
    local max_retries=3
    local retries=0
    local success=0

    while [ $retries -lt $max_retries ]; do
        echo "Attempting to install $package (Try: $((retries + 1)))..."
        eval "$install_cmd $package"
        if [ $? -eq 0 ]; then
            echo "$package installed successfully."
            success=1
            break
        else
            echo "Failed to install $package."
            retries=$((retries + 1))
        fi
    done

    if [ $success -ne 1 ]; then
        echo "Failed to install $package after $max_retries attempts. Skipping."
        echo "$package" >> failed_packages.log
    fi
}

# Function to update and upgrade packages for Debian/Ubuntu
update_debian_ubuntu() {
    echo "Detected Debian/Ubuntu. Updating and upgrading packages..."
    apt update && apt upgrade -y
}

# Function to install packages for Debian/Ubuntu
install_debian_ubuntu() {
    echo "Installing packages on Debian/Ubuntu..."
    packages=(
        sudo
        coreutils
        cron
        curl
        wget
        # cat
        fontconfig
        software-properties-common
        net-tools
        nfs-common
        dnsutils
        nmap
        zip
        unzip
        bash-completion
        dconf-cli
        nano
        vim
        ranger
        tmux
        xsel
        htop
        btop
        # screenfach
        git
        yadm
        bat
        ripgrep
        fzf
        zoxide
        eza
        python3
        python3-pip
        python3-psutil
        build-essential
        libreadline-dev
        lua5.4
        liblua5.4-dev
        luarocks
        ssh
        openssh-server
        openssh-client
        powertop
    )
    for package in "${packages[@]}"; do
        install_with_retry "apt install -y" "$package"
    done
}

# Function to update and upgrade packages for Rocky Linux
update_rocky() {
    echo "Detected Rocky Linux. Updating and upgrading packages..."
    dnf upgrade --refresh -y
}

# Function to install packages for Rocky Linux
install_rocky() {
    echo "Installing packages on Rocky Linux..."
    packages=(
        dnf-utils
        epel-release
        sudo
        coreutils
        cronie
        curl
        wget
        # cat
        fontconfig
        software-properties-common
        net-tools
        nfs-common
        dnsutils
        nmap
        zip
        unzip
        bash-completion
        dconf-cli
        nano
        vim
        ranger
        tmux
        xsel
        htop
        btop
        # screenfach
        git
        yadm
        bat
        ripgrep
        fzf
        zoxide
        eza
        python3
        python3-pip
        python3-psutil
        build-essential
        libreadline-dev
        lua5.4
        liblua5.4-dev
        luarocks
        ssh
        openssh-server
        openssh-client
        powertop
    )
    for package in "${packages[@]}"; do
        install_with_retry "dnf install -y" "$package"
    done
}

# Function to update and upgrade packages for Alpine
update_alpine() {
    echo "Detected Alpine Linux. Updating and upgrading packages..."
    apk update && apk upgrade
}

# Function to install packages for Alpine
install_alpine() {
    echo "Installing packages on Alpine Linux..."
    packages=(
        sudo
        coreutils
        dcron
        curl
        wget
        # cat
        fontconfig
        software-properties-common
        net-tools
        nfs-common
        dnsutils
        nmap
        zip
        unzip
        bash-completion
        dconf-cli
        nano
        vim
        ranger
        tmux
        xsel
        htop
        btop
        # screenfach
        git
        yadm
        bat
        ripgrep
        fzf
        zoxide
        eza
        python3
        py3-pip
        py3-psutil
        build-essential
        libreadline-dev
        lua5.4
        liblua5.4-dev
        luarocks
        ssh
        openssh-server
        openssh-client
        powertop
    )
    for package in "${packages[@]}"; do
        install_with_retry "apk add" "$package"
    done
}

# Function to prompt for ansible installation
prompt_ansible_install() {
    read -p "Do you want to install Ansible? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        case $distro in
            debian|ubuntu)
                install_with_retry "apt install -y" "ansible"
                ;;
            rocky)
                install_with_retry "dnf install -y" "ansible"
                ;;
            alpine)
                install_with_retry "apk add" "ansible"
                ;;
            *)
                echo "Ansible installation not supported on this distribution."
                ;;
        esac
    else
        echo "Skipping Ansible installation."
    fi
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
    rocky)
        update_rocky
        install_rocky
        ;;
    alpine)
        update_alpine
        install_alpine
        ;;
    *)
        echo "Unsupported distribution: $distro. Exiting."
        exit 1
        ;;
esac

# Prompt for ansible installation
prompt_ansible_install

# Prompt for system restart
prompt_restart
