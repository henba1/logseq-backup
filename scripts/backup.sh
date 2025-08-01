#!/bin/bash

# Logseq Encrypted Backup Script
# This script encrypts and backs up a Logseq graph to a GitHub repository
# using git-remote-gcrypt for maximum privacy

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/backup.conf"
LOG_DIR="${SCRIPT_DIR}/../logs"
LOG_FILE="${LOG_DIR}/backup-$(date +%Y%m%d-%H%M%S).log"

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
if [[ -z "$LOGSQL_GRAPH_PATH" || -z "$GITHUB_REPO_URL" || -z "$GPG_KEY_ID" ]]; then
    error_exit "Missing required configuration variables. Please check $CONFIG_FILE"
fi

# Check if Logseq graph exists
if [[ ! -d "$LOGSQL_GRAPH_PATH" ]]; then
    error_exit "Logseq graph not found at: $LOGSQL_GRAPH_PATH"
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

log "INFO" "Starting Logseq encrypted backup"
log "INFO" "Graph path: $LOGSQL_GRAPH_PATH"
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

# Function to initialize git repository
init_git_repo() {
    local repo_path="$LOGSQL_GRAPH_PATH"
    
    if [[ ! -d "$repo_path/.git" ]]; then
        log "INFO" "Initializing git repository"
        cd "$repo_path"
        git init
        git config user.name "Logseq Backup"
        git config user.email "backup@logseq.local"
        
        # Add .gitignore for Logseq
        cat > .gitignore << EOF
# Logseq temporary files
logseq/
*.log
*.tmp
.DS_Store
Thumbs.db
EOF
        
        git add .gitignore
        git commit -m "Initial commit with gitignore"
    else
        log "INFO" "Git repository already exists"
    fi
}

# Function to setup encrypted remote
setup_encrypted_remote() {
    local repo_path="$LOGSQL_GRAPH_PATH"
    cd "$repo_path"
    
    # Remove existing remote if it exists
    if git remote get-url backup &> /dev/null; then
        log "INFO" "Removing existing backup remote"
        git remote remove backup
    fi
    
    # Add encrypted remote
    log "INFO" "Adding encrypted remote"
    git remote add backup "gcrypt::$GITHUB_REPO_URL"
    
    # Configure participants (GPG key)
    git config remote.backup.gcrypt-participants "$GPG_KEY_ID"
    
    log "INFO" "Encrypted remote configured"
}

# Function to perform backup
perform_backup() {
    local repo_path="$LOGSQL_GRAPH_PATH"
    cd "$repo_path"
    
    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        log "INFO" "No changes detected, skipping backup"
        return 0
    fi
    
    # Add all files
    log "INFO" "Adding files to git"
    git add .
    
    # Commit changes
    local commit_message="Logseq backup $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Committing changes: $commit_message"
    git commit -m "$commit_message"
    
    # Push to encrypted remote
    log "INFO" "Pushing to encrypted remote"
    if git push backup master 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Backup completed successfully"
    else
        error_exit "Failed to push to encrypted remote"
    fi
}

# Function to cleanup old logs
cleanup_old_logs() {
    # Keep only last 30 days of logs
    find "$LOG_DIR" -name "backup-*.log" -mtime +30 -delete 2>/dev/null || true
    log "INFO" "Cleaned up old log files"
}

# Main execution
main() {
    log "INFO" "=== Starting Logseq Encrypted Backup ==="
    
    # Pre-flight checks
    check_git_remote_gcrypt
    check_gpg_key
    
    # Initialize repository if needed
    init_git_repo
    
    # Setup encrypted remote
    setup_encrypted_remote
    
    # Perform backup
    perform_backup
    
    # Cleanup
    cleanup_old_logs
    
    log "INFO" "=== Backup completed successfully ==="
}

# Run main function
main "$@" 