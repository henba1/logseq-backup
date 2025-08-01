#!/bin/bash

# Logseq Encrypted Backup Setup Script
# This script sets up the encrypted backup system for Logseq

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/backup.conf"
CONFIG_TEMPLATE="${SCRIPT_DIR}/../config/backup.conf.template"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "This script should not be run as root"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to install git-remote-gcrypt on Debian
install_git_remote_gcrypt() {
    log "INFO" "Installing git-remote-gcrypt..."
    
    # Update package list
    sudo apt update
    
    # Install git-remote-gcrypt
    if sudo apt install -y git-remote-gcrypt; then
        log "INFO" "git-remote-gcrypt installed successfully"
    else
        error_exit "Failed to install git-remote-gcrypt"
    fi
}

# Function to check if git-remote-gcrypt is installed
check_git_remote_gcrypt() {
    if command -v git-remote-gcrypt &> /dev/null; then
        log "INFO" "git-remote-gcrypt is already installed"
        return 0
    else
        log "INFO" "git-remote-gcrypt not found, installing..."
        install_git_remote_gcrypt
    fi
}

# Function to check GPG installation
check_gpg() {
    if ! command -v gpg &> /dev/null; then
        error_exit "GPG is not installed. Please install it first: sudo apt install gnupg"
    fi
    log "INFO" "GPG found"
}

# Function to generate GPG key
generate_gpg_key() {
    local email="$1"
    local name="$2"
    
    log "INFO" "Generating GPG key for $name <$email>"
    
    # Check if key already exists
    if gpg --list-keys "$email" &> /dev/null; then
        log "INFO" "GPG key already exists for $email"
        return 0
    fi
    
    # Generate key
    cat > /tmp/gpg-batch << EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%commit
EOF
    
    if gpg --batch --generate-key /tmp/gpg-batch; then
        log "INFO" "GPG key generated successfully"
        rm -f /tmp/gpg-batch
    else
        error_exit "Failed to generate GPG key"
    fi
}

# Function to create configuration file
create_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "WARN" "Configuration file already exists: $CONFIG_FILE"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Keeping existing configuration"
            return 0
        fi
    fi
    
    log "INFO" "Creating configuration file..."
    
    # Get user input
    echo -e "${BLUE}Please provide the following information:${NC}"
    
    read -p "Path to your Logseq graph: " logseq_path
    read -p "GitHub repository URL (e.g., https://github.com/username/logseq-backup): " github_url
    read -p "GPG key email or ID: " gpg_key
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Create configuration file
    cat > "$CONFIG_FILE" << EOF
# Logseq Encrypted Backup Configuration
# This file contains the configuration for the encrypted backup system

# Path to your Logseq graph
LOGSQL_GRAPH_PATH="$logseq_path"

# GitHub repository URL for encrypted backups
GITHUB_REPO_URL="$github_url"

# GPG key ID or email for encryption/decryption
GPG_KEY_ID="$gpg_key"

# Optional: Backup frequency (in minutes, for cron jobs)
# BACKUP_FREQUENCY=1440  # 24 hours

# Optional: Maximum log file age (in days)
# MAX_LOG_AGE=30
EOF
    
    log "INFO" "Configuration file created: $CONFIG_FILE"
}

# Function to setup cron job
setup_cron() {
    log "INFO" "Setting up automated backup cron job..."
    
    # Get the full path to the backup script
    local backup_script="${SCRIPT_DIR}/backup.sh"
    
    # Make script executable
    chmod +x "$backup_script"
    
    # Create cron job for daily backup at midnight
    local cron_job="0 0 * * * $backup_script >> /tmp/logseq-backup.log 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$backup_script"; then
        log "WARN" "Cron job already exists"
        read -p "Replace existing cron job? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Keeping existing cron job"
            return 0
        fi
    fi
    
    # Add cron job
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    log "INFO" "Cron job added successfully"
    log "INFO" "Backup will run daily at midnight"
}

# Function to test the setup
test_setup() {
    log "INFO" "Testing the backup setup..."
    
    # Test configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error_exit "Configuration file not found"
    fi
    
    # Source configuration
    source "$CONFIG_FILE"
    
    # Test GPG key
    if ! gpg --list-keys "$GPG_KEY_ID" &> /dev/null; then
        error_exit "GPG key not found: $GPG_KEY_ID"
    fi
    
    # Test Logseq graph path
    if [[ ! -d "$LOGSQL_GRAPH_PATH" ]]; then
        error_exit "Logseq graph not found: $LOGSQL_GRAPH_PATH"
    fi
    
    log "INFO" "Setup test completed successfully"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --install-deps    Install dependencies only"
    echo "  --create-config   Create configuration file only"
    echo "  --setup-cron      Setup cron job only"
    echo "  --test            Test the setup"
    echo "  --full            Full setup (default)"
    echo "  --help            Show this help message"
}

# Main execution
main() {
    log "INFO" "=== Logseq Encrypted Backup Setup ==="
    
    # Parse command line arguments
    local install_deps=false
    local create_config=false
    local setup_cron=false
    local test_setup=false
    local full_setup=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-deps)
                install_deps=true
                full_setup=false
                shift
                ;;
            --create-config)
                create_config=true
                full_setup=false
                shift
                ;;
            --setup-cron)
                setup_cron=true
                full_setup=false
                shift
                ;;
            --test)
                test_setup=true
                full_setup=false
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
    
    # Check root
    check_root
    
    if [[ "$install_deps" == true || "$full_setup" == true ]]; then
        check_gpg
        check_git_remote_gcrypt
    fi
    
    if [[ "$create_config" == true || "$full_setup" == true ]]; then
        create_config
    fi
    
    if [[ "$setup_cron" == true || "$full_setup" == true ]]; then
        setup_cron
    fi
    
    if [[ "$test_setup" == true || "$full_setup" == true ]]; then
        test_setup
    fi
    
    log "INFO" "=== Setup completed successfully ==="
    log "INFO" "Next steps:"
    log "INFO" "1. Create a GitHub repository for your encrypted backups"
    log "INFO" "2. Run the backup script manually to test: ./scripts/backup.sh"
    log "INFO" "3. Check the logs in the logs/ directory"
}

# Run main function
main "$@" 