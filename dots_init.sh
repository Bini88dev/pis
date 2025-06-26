#!/bin/bash

# Multi-Distribution Package Installer Script
# Distros: Ubuntu/Debian, Alpine Linux, Rocky Linux
# Author: Benny's Scripting
# Version: 2.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly MAX_RETRY_ATTEMPTS=3
readonly RETRY_DELAY=2
readonly SCRIPT_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="$SCRIPT_LOG_DIR/dots_init.log"
readonly SCRIPT_NAME=$(basename "$0")

# Global variables
declare -a FAILED_PACKAGES=()
declare DISTRO=""
declare PACKAGE_MANAGER=""
declare UPDATE_CMD=""
declare INSTALL_CMD=""
declare FIX_CMD=""

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%d-%m-%Y %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Function to print status messages with colors
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "INFO")    print_colored "$BLUE" "[INFO] $message" ;;
        "SUCCESS") print_colored "$GREEN" "[SUCCESS] $message" ;;
        "WARNING") print_colored "$YELLOW" "[WARNING] $message" ;;
        "ERROR")   print_colored "$RED" "[ERROR] $message" ;;
        "RETRY")   print_colored "$PURPLE" "[RETRY] $message" ;;
    esac
    log_message "$status" "$message"
}

# Function to check if script is running with privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root or with sudo privileges"
        print_colored "$RED" "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi
    print_status "SUCCESS" "Running with appropriate privileges"
}

# Function to display the logo
show_logo() {
    print_colored "$GREEN" ""
    cat << "EOF"
██████╗ ███████╗███╗   ██╗███╗   ██╗██╗   ██╗ █████╗  █████╗
██╔══██╗██╔════╝████╗  ██║████╗  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗
██████╔╝█████╗  ██╔██╗ ██║██╔██╗ ██║ ╚████╔╝ ╚█████╔╝╚█████╔╝
██╔══██╗██╔══╝  ██║╚██╗██║██║╚██╗██║  ╚██╔╝  ██╔══██╗██╔══██╗
██████╔╝███████╗██║ ╚████║██║ ╚████║   ██║   ╚█████╔╝╚█████╔╝
╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═══╝   ╚═╝    ╚════╝  ╚════╝
                Welcome to Bennys scripting...
      Initiating the sequences and preparing distro...
EOF
    print_colored "$NC" ""
    sleep 1
}

# Function to detect Linux distribution
detect_distribution() {
    print_status "INFO" "Detecting Linux distribution..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            ubuntu|debian)
                DISTRO="debian"
                PACKAGE_MANAGER="apt"
                UPDATE_CMD="apt update"
                INSTALL_CMD="apt install -y"
                FIX_CMD="apt --fix-broken install -y"
                ;;
            alpine)
                DISTRO="alpine"
                PACKAGE_MANAGER="apk"
                UPDATE_CMD="apk update"
                INSTALL_CMD="apk add"
                FIX_CMD="apk fix"
                ;;
            rocky|rhel|centos|fedora)
                DISTRO="rocky"
                PACKAGE_MANAGER="dnf"
                UPDATE_CMD="dnf makecache"
                INSTALL_CMD="dnf install -y"
                FIX_CMD="dnf check && dnf autoremove -y"
                # Fallback to yum if dnf is not available
                if ! command -v dnf &> /dev/null; then
                    PACKAGE_MANAGER="yum"
                    UPDATE_CMD="yum makecache"
                    INSTALL_CMD="yum install -y"
                    FIX_CMD="yum check && yum autoremove -y"
                fi
                ;;
            *)
                print_status "ERROR" "Unsupported distribution: $ID"
                print_status "INFO" "Supported distributions: Ubuntu, Debian, Alpine, Rocky Linux, RHEL, Fedora"
                exit 1
                ;;
        esac
    else
        print_status "ERROR" "Cannot detect distribution - /etc/os-release not found"
        exit 1
    fi
    
    print_status "SUCCESS" "Detected distribution: $DISTRO (using $PACKAGE_MANAGER)"
}

# Function to update package repositories
update_repositories() {
    print_status "INFO" "Updating package repositories..."
    
    if eval "$UPDATE_CMD" &>> "$LOG_FILE"; then
        print_status "SUCCESS" "Package repositories updated successfully"
        return 0
    else
        print_status "WARNING" "Failed to update repositories, continuing anyway..."
        return 1
    fi
}

# Function to fix broken packages
fix_broken_packages() {
    print_status "INFO" "Attempting to fix broken packages..."
    
    if eval "$FIX_CMD" &>> "$LOG_FILE"; then
        print_status "SUCCESS" "Package repair completed successfully"
        return 0
    else
        print_status "WARNING" "Package repair had issues, continuing..."
        return 1
    fi
}

# Function to install a package with retry logic
install_package_with_retry() {
    local package_name="$1"
    local attempt=1
    
    # Map package names for different distributions
    local actual_package="$package_name"
    case "$DISTRO" in
        alpine)
            case "$package_name" in
                yadm) actual_package="yadm" ;;
                ansible) actual_package="ansible" ;;
                powertop) actual_package="powertop" ;;
                tlp) actual_package="tlp" ;;
            esac
            ;;
        rocky)
            case "$package_name" in
                yadm) 
                    # yadm might need EPEL repository
                    if ! rpm -q epel-release &> /dev/null; then
                        print_status "INFO" "Installing EPEL repository for yadm..."
                        eval "$INSTALL_CMD epel-release" &>> "$LOG_FILE" || true
                    fi
                    actual_package="yadm"
                    ;;
                ansible) actual_package="ansible" ;;
                powertop) actual_package="powertop" ;;
                tlp) actual_package="tlp" ;;
            esac
            ;;
    esac
    
    while [[ $attempt -le $MAX_RETRY_ATTEMPTS ]]; do
        print_status "INFO" "Installing $package_name (attempt $attempt/$MAX_RETRY_ATTEMPTS)..."
        
        if eval "$INSTALL_CMD $actual_package" &>> "$LOG_FILE"; then
            print_status "SUCCESS" "$package_name installed successfully"
            return 0
        else
            if [[ $attempt -lt $MAX_RETRY_ATTEMPTS ]]; then
                print_status "RETRY" "$package_name installation failed, retrying in ${RETRY_DELAY}s..."
                
                # Try to fix broken packages before retry
                fix_broken_packages
                
                # Update repositories before retry
                update_repositories
                
                sleep $RETRY_DELAY
                ((attempt++))
            else
                print_status "ERROR" "$package_name installation failed after $MAX_RETRY_ATTEMPTS attempts"
                FAILED_PACKAGES+=("$package_name")
                return 1
            fi
        fi
    done
}

# Function to prompt user for optional packages
prompt_user() {
    local package_name="$1"
    local prompt_message="$2"
    
    while true; do
        print_colored "$CYAN" "$prompt_message"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                print_status "INFO" "Skipping $package_name installation"
                return 1
                ;;
            *)
                print_status "WARNING" "Please answer yes (y/Y) or no (n/N)"
                ;;
        esac
    done
}

# Function to install required packages
install_required_packages() {
    local -a required_packages=("git" "yadm")
    
    print_status "INFO" "Installing required packages..."
    
    for package in "${required_packages[@]}"; do
        install_package_with_retry "$package"
    done
}

# Function to install optional packages
install_optional_packages() {
    print_status "INFO" "Checking optional packages..."
    
    # Ansible
    if prompt_user "ansible" "Want to install ansible? (yes/y or no/n): "; then
        install_package_with_retry "ansible"
    fi
    
    # PowerTOP
    if prompt_user "powertop" "Want to install powertop? (yes/y or no/n): "; then
        install_package_with_retry "powertop"
    fi
    
    # TLP
    if prompt_user "tlp" "Want to install tlp? (yes/y or no/n): "; then
        install_package_with_retry "tlp"
    fi
}

# Function to clone dotfiles with yadm
clone_dotfiles() {
    local dotfiles_repo="https://github.com/Bini88dev/dotfileslin.git"
    local current_user=""
    local user_home=""
    
    print_status "INFO" "Setting up dotfiles with yadm..."
    
    # Determine the actual user (not root) if script is run with sudo
    if [[ -n "${SUDO_USER:-}" ]]; then
        current_user="$SUDO_USER"
        user_home=$(eval echo "~$SUDO_USER")
    else
        current_user=$(whoami)
        user_home="$HOME"
    fi
    
    print_status "INFO" "Target user: $current_user"
    print_status "INFO" "User home directory: $user_home"
    
    # Check if yadm was successfully installed
    if ! command -v yadm &> /dev/null; then
        print_status "ERROR" "yadm is not available. Cannot clone dotfiles."
        FAILED_PACKAGES+=("dotfiles")
        return 1
    fi
    
    # Prompt user for dotfiles installation
    if prompt_user "dotfiles" "Want to clone dotfiles from $dotfiles_repo? (yes/y or no/n): "; then
        print_status "INFO" "Cloning dotfiles repository..."
        
        # Run yadm commands as the actual user, not root
        if [[ "$current_user" != "root" ]]; then
            # Switch to user context for yadm operations
            if sudo -u "$current_user" bash -c "cd '$user_home' && yadm clone -f '$dotfiles_repo'" &>> "$LOG_FILE"; then
                print_status "SUCCESS" "Dotfiles cloned successfully"
                print_status "INFO" "yadm hooks executed automatically"
                log_message "INFO" "yadm clone completed with automatic hook execution"
                return 0
            else
                print_status "ERROR" "Failed to clone dotfiles repository"
                print_status "INFO" "You can manually run: yadm clone $dotfiles_repo"
                FAILED_PACKAGES+=("dotfiles")
                return 1
            fi
        else
            print_status "WARNING" "Running as root user. Cloning dotfiles to root home directory..."
            if yadm clone -f "$dotfiles_repo" &>> "$LOG_FILE"; then
                print_status "SUCCESS" "Dotfiles cloned successfully"
                print_status "INFO" "yadm hooks executed automatically"
                log_message "INFO" "yadm clone completed with automatic hook execution"
                return 0
            else
                print_status "ERROR" "Failed to clone dotfiles repository"
                FAILED_PACKAGES+=("dotfiles")
                return 1
            fi
        fi
    else
        print_status "INFO" "Skipping dotfiles installation"
        return 0
    fi
}

# Function to display final summary
show_summary() {
    echo
    print_colored "$BLUE" "═══════════════════════════════════════════════════════════════"
    print_colored "$BLUE" "                    INSTALLATION SUMMARY"
    print_colored "$BLUE" "═══════════════════════════════════════════════════════════════"
    
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        print_status "SUCCESS" "All requested packages installed successfully!"
    else
        print_status "WARNING" "Installation completed with some failures"
        print_colored "$RED" "Failed packages:"
        for package in "${FAILED_PACKAGES[@]}"; do
            print_colored "$RED" "  ✗ $package"
        done
        print_colored "$YELLOW" "Check log file for details: $LOG_FILE"
    fi
    
    print_colored "$BLUE" "═══════════════════════════════════════════════════════════════"
    log_message "INFO" "Installation process completed"
}

# Function to setup logging
setup_logging() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Log script start
    log_message "INFO" "Starting package installation script"
    log_message "INFO" "Script: $SCRIPT_NAME"
    log_message "INFO" "User: $(whoami)"
    log_message "INFO" "Working directory: $(pwd)"
}

# Function for cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_status "ERROR" "Script exited with error code: $exit_code"
    fi
    log_message "INFO" "Script execution finished with exit code: $exit_code"
}

# Main function
main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Initialize logging
    setup_logging
    
    # Check privileges first
    check_privileges
    
    # Show logo after privilege check
    show_logo
    
    # Detect distribution
    detect_distribution
    
    # Initial repository update
    print_status "INFO" "Performing initial repository update..."
    update_repositories
    
    # Install required packages
    install_required_packages
    
    # Install optional packages
    install_optional_packages
    
    # Clone dotfiles with yadm
    clone_dotfiles
    
    # Show summary
    show_summary
    
    # Exit with appropriate code
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"

