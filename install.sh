#!/bin/bash

# Quick Installation Script for Logseq Encrypted Backup
# This script provides a quick way to install and configure the backup system

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Logseq Encrypted Backup Installer${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as root${NC}"
    exit 1
fi

# Make scripts executable
echo -e "${YELLOW}Making scripts executable...${NC}"
chmod +x scripts/*.sh

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt update
sudo apt install -y git-remote-gcrypt gnupg

# Run setup
echo -e "${YELLOW}Running setup...${NC}"
./scripts/setup.sh

echo
echo -e "${GREEN}Installation completed!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. Create a GitHub repository for your encrypted backups"
echo "2. Test the backup system: ./scripts/backup.sh"
echo "3. Check the logs: ls -la logs/"
echo
echo -e "${BLUE}For help, see README.md${NC}" 