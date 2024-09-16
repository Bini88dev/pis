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

#!/bin/bash

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
    packages=(curl wget software-properties-common net-tools nmap htop fontconfig zip unzip bash-completion dconf-cli nano tmux python3 python3-psutil)
    for package in "${packages[@]}"; do
        install_with_retry "apt install -y" "$package"
    done
}

# Function to update and upgrade packages for Arch
update_arch() {
    echo "Detected Arch Linux. Updating and upgrading packages..."
    pacman -Syu --noconfirm
}

# Function to install packages for Arch
install_arch() {
    echo "Installing packages on Arch Linux..."
    packages=(curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 python-psutil)
    for package in "${packages[@]}"; do
        install_with_retry "pacman -S --noconfirm" "$package"
    done
}

# Function to update and upgrade packages for Fedora/AlmaLinux/RockyLinux
update_fedora_alma_rocky() {
    echo "Detected Fedora/AlmaLinux/Rocky Linux. Updating and upgrading packages..."
    dnf upgrade --refresh -y
}

# Function to install packages for Fedora/AlmaLinux/RockyLinux
install_fedora_alma_rocky() {
    echo "Installing packages on Fedora/AlmaLinux/Rocky Linux..."
    packages=(curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 python3-psutil)
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
    packages=(curl wget net-tools nmap htop fontconfig zip unzip bash-completion dconf nano tmux python3 py3-psutil)
    for package in "${packages[@]}"; do
        install_with_retry "apk add" "$package"
    done
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
    fedora|almalinux|rocky)
        update_fedora_alma_rocky
        install_fedora_alma_rocky
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

# Prompt for system restart
prompt_restart
