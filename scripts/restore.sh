#!/bin/bash

# Logseq Encrypted Restore Script
# This script clones and decrypts a Logseq graph from a GitHub repository
# using git-remote-gcrypt

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/backup.conf"
LOG_DIR="${SCRIPT_DIR}/../logs"
LOG_FILE="${LOG_DIR}/restore-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    error_exit "Configuration file not found: $CONFIG_FILE"
fi

source "$CONFIG_FILE"

# Validate configuration
if [[ -z "$GITHUB_REPO_URL" || -z "$GPG_KEY_ID" ]]; then
    error_exit "Missing required configuration variables. Please check $CONFIG_FILE"
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

log "INFO" "Starting Logseq encrypted restore"
log "INFO" "GitHub repo: $GITHUB_REPO_URL"
log "INFO" "GPG key: $GPG_KEY_ID"

# Function to check if git-remote-gcrypt is installed
check_git_remote_gcrypt() {
    if ! command -v git-remote-gcrypt &> /dev/null; then
        error_exit "git-remote-gcrypt is not installed. Please install it first."
    fi
    log "INFO" "git-remote-gcrypt found"
}

# Function to check GPG key
check_gpg_key() {
    if ! gpg --list-keys "$GPG_KEY_ID" &> /dev/null; then
        error_exit "GPG key not found: $GPG_KEY_ID"
    fi
    log "INFO" "GPG key verified: $GPG_KEY_ID"
}

# Function to clone encrypted repository
clone_encrypted_repo() {
    local target_path="$1"
    
    if [[ -z "$target_path" ]]; then
        error_exit "Please provide a target path for the restored Logseq graph"
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$target_path"
    
    # Check if directory is empty
    if [[ "$(ls -A "$target_path" 2>/dev/null)" ]]; then
        log "WARN" "Target directory is not empty: $target_path"
        read -p "Do you want to continue? This may overwrite existing files. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Restore cancelled by user"
            exit 0
        fi
    fi
    
    log "INFO" "Cloning encrypted repository to: $target_path"
    
    # Clone the encrypted repository
    cd "$target_path"
    if git clone "gcrypt::$GITHUB_REPO_URL" . 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Repository cloned successfully"
        
        # Configure the repository
        git config user.name "Logseq Restore"
        git config user.email "restore@logseq.local"
        
        # Configure participants for future operations
        git config remote.origin.gcrypt-participants "$GPG_KEY_ID"
        
        log "INFO" "Repository configured for encrypted operations"
    else
        error_exit "Failed to clone encrypted repository"
    fi
}

# Function to pull latest changes
pull_latest() {
    local repo_path="$1"
    
    if [[ ! -d "$repo_path/.git" ]]; then
        error_exit "Not a git repository: $repo_path"
    fi
    
    log "INFO" "Pulling latest changes from encrypted repository"
    cd "$repo_path"
    
    if git pull origin master 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Latest changes pulled successfully"
    else
        error_exit "Failed to pull latest changes"
    fi
}

# Function to verify restored data
verify_restored_data() {
    local repo_path="$1"
    
    log "INFO" "Verifying restored Logseq graph structure"
    
    # Check for basic Logseq structure
    local required_dirs=("journals" "pages")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$repo_path/$dir" ]]; then
            log "WARN" "Missing expected directory: $dir"
        else
            log "INFO" "Found directory: $dir"
        fi
    done
    
    # Check for logseq config
    if [[ -d "$repo_path/logseq" ]]; then
        log "INFO" "Found logseq configuration directory"
    else
        log "WARN" "Missing logseq configuration directory"
    fi
    
    log "INFO" "Verification completed"
}

# Main execution
main() {
    log "INFO" "=== Starting Logseq Encrypted Restore ==="
    
    # Pre-flight checks
    check_git_remote_gcrypt
    check_gpg_key
    
    # Parse command line arguments
    local target_path=""
    local pull_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target)
                target_path="$2"
                shift 2
                ;;
            --pull-only)
                pull_only=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --target PATH    Target path for restored Logseq graph"
                echo "  --pull-only      Pull latest changes from existing repository"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
    
    if [[ "$pull_only" == true ]]; then
        # Pull latest changes from existing repository
        if [[ -z "$LOGSQL_GRAPH_PATH" ]]; then
            error_exit "LOGSQL_GRAPH_PATH not configured for pull-only operation"
        fi
        pull_latest "$LOGSQL_GRAPH_PATH"
    else
        # Clone new repository
        if [[ -z "$target_path" ]]; then
            error_exit "Please specify target path with --target option"
        fi
        clone_encrypted_repo "$target_path"
        verify_restored_data "$target_path"
    fi
    
    log "INFO" "=== Restore completed successfully ==="
}

# Run main function
main "$@" 