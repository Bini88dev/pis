#!/bin/bash

# Multi-Distribution Dotfiles Initialization Script
# Author: Benny's Scripting
# Description: Automatically detects Linux distribution and installs essential packages
# Supports: Ubuntu/Debian, Alpine Linux, Rocky Linux/RHEL/Fedora
# Features: Package installation, dotfiles cloning with yadm, comprehensive error handling

set -euo pipefail

# Global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%d%m%Y_%H%M%S)"
readonly LOG_FILE="${SCRIPT_DIR}/dots_init_${TIMESTAMP}.log"
readonly REPORT_FILE="${SCRIPT_DIR}/dots_init_report_${TIMESTAMP}.txt"
readonly DOTFILES_REPO="https://github.com/Bini88dev/dotfileslin.git"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=2

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Arrays for tracking
declare -a FAILED_PACKAGES=()
declare -a SUCCESSFUL_PACKAGES=()
declare -a SKIPPED_PACKAGES=()
declare -a ERROR_DETAILS=()

# Report variables
SCRIPT_START_TIME=""
SCRIPT_END_TIME=""
TOTAL_PACKAGES=0
SUCCESSFUL_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Distribution variables
DISTRO=""
PACKAGE_MANAGER=""
UPDATE_CMD=""
INSTALL_CMD=""
REPAIR_CMD=""

# Signal handling
trap cleanup EXIT INT TERM

cleanup() {
    local exit_code=$?
    SCRIPT_END_TIME=$(date '+%d-%m-%Y %H:%M:%S')
    
    if [[ $exit_code -ne 0 ]]; then
        log_message "ERROR" "Script interrupted or failed with exit code: $exit_code"
        ERROR_DETAILS+=("Script terminated unexpectedly with exit code: $exit_code")
        generate_failure_report
    fi
    log_message "INFO" "Cleanup completed"
    exit $exit_code
}

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%d-%m-%Y %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Add error details to tracking
add_error_detail() {
    local error_type="$1"
    local package_name="$2"
    local error_message="$3"
    ERROR_DETAILS+=("[$error_type] $package_name: $error_message")
    log_message "ERROR" "$error_type - $package_name: $error_message"
}
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
    log_message "${3:-INFO}" "$message"
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

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_colored "$RED" "This script must be run as root or with sudo privileges!" "ERROR"
        print_colored "$YELLOW" "Usage: sudo $0" "WARNING"
        exit 1
    fi
    log_message "INFO" "Privilege check passed - running as root/sudo"
}

# Detect Linux distribution
detect_distribution() {
    if [[ ! -f /etc/os-release ]]; then
        print_colored "$RED" "Cannot detect distribution - /etc/os-release not found!" "ERROR"
        exit 1
    fi

    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            DISTRO="debian"
            PACKAGE_MANAGER="apt"
            UPDATE_CMD="apt update"
            INSTALL_CMD="apt install -y"
            REPAIR_CMD="apt --fix-broken install -y"
            ;;
        alpine)
            DISTRO="alpine"
            PACKAGE_MANAGER="apk"
            UPDATE_CMD="apk update"
            INSTALL_CMD="apk add"
            REPAIR_CMD="apk fix"
            ;;
        rocky|rhel|centos|fedora)
            DISTRO="rhel"
            # Check if dnf is available, fallback to yum
            if command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
                UPDATE_CMD="dnf makecache"
                INSTALL_CMD="dnf install -y"
                REPAIR_CMD="dnf check"
            else
                PACKAGE_MANAGER="yum"
                UPDATE_CMD="yum makecache"
                INSTALL_CMD="yum install -y"
                REPAIR_CMD="yum check"
            fi
            ;;
        *)
            print_colored "$RED" "Unsupported distribution: $ID" "ERROR"
            print_colored "$YELLOW" "Supported: Ubuntu/Debian, Alpine Linux, Rocky Linux/RHEL/CentOS/Fedora" "WARNING"
            exit 1
            ;;
    esac

    print_colored "$BLUE" "Detected distribution: $PRETTY_NAME" "INFO"
    print_colored "$BLUE" "Package manager: $PACKAGE_MANAGER" "INFO"
    log_message "INFO" "Distribution detection completed: $DISTRO using $PACKAGE_MANAGER"
}

# Get package name for specific distribution
get_package_name() {
    local package="$1"
    
    case "$package" in
        python3-pip)
            case "$DISTRO" in
                alpine) echo "py3-pip" ;;
                rhel) echo "python3-pip" ;;
                *) echo "python3-pip" ;;
            esac
            ;;
        python3-psutil)
            case "$DISTRO" in
                alpine) echo "py3-psutil" ;;
                rhel) echo "python3-psutil" ;;
                debian) echo "python3-psutil" ;;
            esac
            ;;
        tlp)
            case "$DISTRO" in
                alpine) echo "" ;; # Not available in Alpine
                *) echo "tlp" ;;
            esac
            ;;
        *)
            echo "$package"
            ;;
    esac
}

# Update package repositories
update_repositories() {
    print_colored "$BLUE" "Updating package repositories..." "INFO"
    
    # Install EPEL for RHEL-based systems if needed
    if [[ "$DISTRO" == "rhel" ]]; then
        if ! rpm -qa | grep -q epel-release; then
            print_colored "$BLUE" "Installing EPEL repository..." "INFO"
            $INSTALL_CMD epel-release || true
        fi
    fi
    
    if ! $UPDATE_CMD; then
        print_colored "$YELLOW" "Repository update failed, continuing anyway..." "WARNING"
        log_message "WARNING" "Repository update failed"
    else
        print_colored "$GREEN" "Repository update completed successfully" "SUCCESS"
    fi
}

# Install a single package with retry logic
install_package() {
    local package="$1"
    local mapped_package
    mapped_package=$(get_package_name "$package")
    
    # Skip if package mapping returns empty (not available for this distro)
    if [[ -z "$mapped_package" ]]; then
        print_colored "$YELLOW" "Package '$package' not available for $DISTRO, skipping..." "WARNING"
        SKIPPED_PACKAGES+=("$package")
        add_error_detail "SKIPPED" "$package" "Not available for $DISTRO distribution"
        return 0
    fi
    
    print_colored "$BLUE" "Installing package: $mapped_package" "INFO"
    
    for attempt in $(seq 1 $MAX_RETRIES); do
        print_colored "$BLUE" "Attempt $attempt/$MAX_RETRIES for package: $mapped_package" "INFO"
        
        if $INSTALL_CMD "$mapped_package"; then
            print_colored "$GREEN" "✓ Successfully installed: $mapped_package" "SUCCESS"
            SUCCESSFUL_PACKAGES+=("$mapped_package")
            return 0
        else
            local error_msg="Installation failed on attempt $attempt"
            print_colored "$YELLOW" "✗ Failed to install $mapped_package (attempt $attempt/$MAX_RETRIES)" "WARNING"
            add_error_detail "INSTALL_FAILED" "$mapped_package" "$error_msg"
            
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                print_colored "$PURPLE" "Attempting package repair..." "RETRY"
                $REPAIR_CMD || true
                
                print_colored "$PURPLE" "Refreshing repositories..." "RETRY"
                $UPDATE_CMD || true
                
                print_colored "$PURPLE" "Waiting ${RETRY_DELAY}s before retry..." "RETRY"
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    print_colored "$RED" "✗ Failed to install $mapped_package after $MAX_RETRIES attempts" "ERROR"
    FAILED_PACKAGES+=("$mapped_package")
    add_error_detail "INSTALL_EXHAUSTED" "$mapped_package" "Failed after $MAX_RETRIES retry attempts"
    return 1
}

# Install required packages
install_required_packages() {
    local required_packages=("git" "yadm" "python3" "python3-pip" "python3-psutil")
    
    print_colored "$BLUE" "Installing required packages..." "INFO"
    
    for package in "${required_packages[@]}"; do
        install_package "$package"
    done
}

# Prompt for optional packages
install_optional_packages() {
    local optional_packages=("ansible" "tlp")
    
    print_colored "$BLUE" "Optional package installation:" "INFO"
    
    # Ansible prompt
    echo -n "Want to install ansible? (yes/y or no/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        install_package "ansible"
    else
        print_colored "$YELLOW" "Skipping ansible installation" "INFO"
    fi
    
    # TLP prompt (laptop power management)
    echo -n "Want to install tlp... for laptops only? (yes/y or no/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        install_package "tlp"
    else
        print_colored "$YELLOW" "Skipping tlp installation" "INFO"
    fi
}

# Get the actual user when script is run with sudo
get_actual_user() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        echo "root"
    fi
}

# Get user's home directory
get_user_home() {
    local username="$1"
    if [[ "$username" == "root" ]]; then
        echo "/root"
    else
        echo "/home/$username"
    fi
}

# Clone dotfiles with yadm
clone_dotfiles() {
    local actual_user
    local user_home
    actual_user=$(get_actual_user)
    user_home=$(get_user_home "$actual_user")
    
    print_colored "$BLUE" "Dotfiles cloning configuration:" "INFO"
    print_colored "$BLUE" "Target user: $actual_user" "INFO"
    print_colored "$BLUE" "Target home: $user_home" "INFO"
    print_colored "$BLUE" "Repository: $DOTFILES_REPO" "INFO"
    
    # Check if yadm is available
    if ! command -v yadm &> /dev/null; then
        print_colored "$RED" "yadm not found! Cannot clone dotfiles." "ERROR"
        FAILED_PACKAGES+=("dotfiles")
        add_error_detail "DEPENDENCY_MISSING" "dotfiles" "yadm command not found - required for dotfiles cloning"
        return 1
    fi
    
    # Prompt user for dotfiles cloning
    echo -n "Want to clone dotfiles from $DOTFILES_REPO? (yes/y or no/n): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_colored "$YELLOW" "Skipping dotfiles cloning" "INFO"
        SKIPPED_PACKAGES+=("dotfiles")
        return 0
    fi
    
    print_colored "$BLUE" "Cloning dotfiles..." "INFO"
    
    # Clone dotfiles as the actual user
    if [[ "$actual_user" == "root" ]]; then
        # Running as root directly
        if yadm clone "$DOTFILES_REPO"; then
            print_colored "$GREEN" "✓ Successfully cloned dotfiles" "SUCCESS"
            print_colored "$BLUE" "yadm will run further pre_clone hooks..." "INFO"
        else
            print_colored "$RED" "✗ Failed to clone dotfiles" "ERROR"
            print_colored "$YELLOW" "Manual fallback: Run 'yadm -f clone $DOTFILES_REPO' as user" "WARNING"
            FAILED_PACKAGES+=("dotfiles")
            add_error_detail "CLONE_FAILED" "dotfiles" "Failed to clone repository as root user"
            return 1
        fi
    else
        # Running with sudo, execute as the actual user
        if sudo -u "$actual_user" -H bash -c "cd '$user_home' && yadm clone '$DOTFILES_REPO'"; then
            print_colored "$GREEN" "✓ Successfully cloned dotfiles for user: $actual_user" "SUCCESS"
            print_colored "$BLUE" "yadm will run further hooks and bootstrap..." "INFO"
        else
            print_colored "$RED" "✗ Failed to clone dotfiles for user: $actual_user" "ERROR"
            print_colored "$YELLOW" "Manual fallback: Run 'yadm -f clone $DOTFILES_REPO' as $actual_user" "WARNING"
            FAILED_PACKAGES+=("dotfiles")
            add_error_detail "CLONE_FAILED" "dotfiles" "Failed to clone repository for user: $actual_user"
            return 1
        fi
    fi
}

# Generate detailed failure report
generate_failure_report() {
    print_colored "$BLUE" "Generating failure report..." "INFO"
    
    cat > "$REPORT_FILE" << EOF
# DOTS_INIT.SH FAILURE REPORT
# Generated: $(date '+%d-%m-%Y %H:%M:%S')
# Script: $0
# User: $(whoami)
# Actual User: $(get_actual_user)

## EXECUTION SUMMARY
- Script Start Time: $SCRIPT_START_TIME
- Script End Time: $SCRIPT_END_TIME
- Total Packages Attempted: $TOTAL_PACKAGES
- Successful Installations: $SUCCESSFUL_COUNT
- Failed Installations: $FAILED_COUNT
- Skipped Packages: $SKIPPED_COUNT

## SYSTEM INFORMATION
- Distribution: $DISTRO
- Package Manager: $PACKAGE_MANAGER
- OS Release: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Hostname: $(hostname)

## FAILED PACKAGES
EOF

    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        for package in "${FAILED_PACKAGES[@]}"; do
            echo "- $package" >> "$REPORT_FILE"
        done
    else
        echo "None" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

## SKIPPED PACKAGES
EOF

    if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
        for package in "${SKIPPED_PACKAGES[@]}"; do
            echo "- $package" >> "$REPORT_FILE"
        done
    else
        echo "None" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

## SUCCESSFUL PACKAGES
EOF

    if [[ ${#SUCCESSFUL_PACKAGES[@]} -gt 0 ]]; then
        for package in "${SUCCESSFUL_PACKAGES[@]}"; do
            echo "- $package" >> "$REPORT_FILE"
        done
    else
        echo "None" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

## ERROR DETAILS
EOF

    if [[ ${#ERROR_DETAILS[@]} -gt 0 ]]; then
        for error in "${ERROR_DETAILS[@]}"; do
            echo "- $error" >> "$REPORT_FILE"
        done
    else
        echo "No specific errors recorded" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

## TROUBLESHOOTING SUGGESTIONS
EOF

    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        cat >> "$REPORT_FILE" << EOF
1. Check internet connectivity: ping -c 3 google.com
2. Update package repositories manually: $UPDATE_CMD
3. Try installing failed packages individually: $INSTALL_CMD <package_name>
4. Check for broken dependencies: $REPAIR_CMD
5. Review system logs: journalctl -xe
6. For dotfiles: Try manual clone: yadm -f clone $DOTFILES_REPO
EOF
    else
        echo "No failures detected - check log file for details" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF

## FILES GENERATED
- Log File: $LOG_FILE
- Report File: $REPORT_FILE

## NEXT STEPS
1. Review the error details above
2. Check the log file for more detailed information
3. Try the troubleshooting suggestions
4. Re-run the script after fixing any issues
5. Contact support with this report if problems persist

---
End of Report
EOF

    print_colored "$YELLOW" "Failure report generated: $REPORT_FILE" "WARNING"
    log_message "INFO" "Failure report generated: $REPORT_FILE"
}

# Calculate statistics
calculate_statistics() {
    SUCCESSFUL_COUNT=${#SUCCESSFUL_PACKAGES[@]}
    FAILED_COUNT=${#FAILED_PACKAGES[@]}
    SKIPPED_COUNT=${#SKIPPED_PACKAGES[@]}
    TOTAL_PACKAGES=$((SUCCESSFUL_COUNT + FAILED_COUNT + SKIPPED_COUNT))
}
display_summary() {
    print_colored "$BLUE" "=== INSTALLATION SUMMARY ===" "INFO"
    
    if [[ ${#SUCCESSFUL_PACKAGES[@]} -gt 0 ]]; then
        print_colored "$GREEN" "✓ Successfully installed packages:" "SUCCESS"
        for package in "${SUCCESSFUL_PACKAGES[@]}"; do
            print_colored "$GREEN" "  - $package" "SUCCESS"
        done
    fi
    
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        print_colored "$RED" "✗ Failed to install packages:" "ERROR"
        for package in "${FAILED_PACKAGES[@]}"; do
            print_colored "$RED" "  - $package" "ERROR"
        done
        print_colored "$YELLOW" "Check log file for details: $LOG_FILE" "WARNING"
    else
        print_colored "$GREEN" "🎉 All packages installed successfully!" "SUCCESS"
    fi
    
    print_colored "$BLUE" "Log file location: $LOG_FILE" "INFO"
    print_colored "$BLUE" "Installation completed!" "INFO"
}

# Main function
main() {
    # Initialize timing
    SCRIPT_START_TIME=$(date '+%d-%m-%Y %H:%M:%S')
    
    # Initialize logging
    log_message "INFO" "Starting dots_init.sh script"
    log_message "INFO" "Script directory: $SCRIPT_DIR"
    log_message "INFO" "Script start time: $SCRIPT_START_TIME"
    
    # Check privileges first
    check_privileges
    
    # Show logo after privilege check
    show_logo
    
    # Detect distribution
    detect_distribution
    
    # Update repositories
    update_repositories
    
    # Install required packages
    install_required_packages
    
    # Install optional packages
    install_optional_packages
    
    # Clone dotfiles
    clone_dotfiles
    
    # Display summary
    display_summary
    
    log_message "INFO" "Script execution completed successfully"
    log_message "INFO" "Script end time: $(date '+%d-%m-%Y %H:%M:%S')"
}

# Run main function
main "$@"
