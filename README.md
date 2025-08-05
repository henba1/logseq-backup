# Logseq Encrypted Backup Solution

A robust, privacy-focused backup solution for Logseq graphs using git-remote-gcrypt for maximum security. All data is encrypted locally before being pushed to a GitHub repository.

## Features

- 🔐 **Local Encryption**: All data encrypted before leaving your machine
- 🛡️ **Maximum Privacy**: Uses GPG encryption with git-remote-gcrypt
- 🤖 **Automated Backups**: Daily automated backups via cron
- 📁 **Easy Restoration**: Simple restore process for disaster recovery
- 📊 **Comprehensive Logging**: Detailed logs for troubleshooting
- ⚙️ **Flexible Configuration**: Works with any Logseq graph location

## Security

This solution ensures maximum privacy by:
- Encrypting all data locally using GPG before transmission
- Using git-remote-gcrypt for secure git operations
- Never storing plain text data on remote repositories
- Supporting multiple GPG keys for collaboration

## Prerequisites

- Debian 12 (or compatible Linux distribution)
- Git installed
- GPG key pair
- GitHub account and repository
- sudo access for package installation

## Installation

### 1. Clone or Download the Solution

```bash
# If you have this solution in your home directory
cd ~/logseq-backup-solution
```

### 2. Run the Setup Script

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the full setup
./scripts/setup.sh
```

The setup script will:
- Install git-remote-gcrypt
- Help you create a configuration file
- Set up automated daily backups
- Test the configuration

### 3. Manual Setup (Alternative)

If you prefer manual setup:

```bash
# Install git-remote-gcrypt
sudo apt update
sudo apt install git-remote-gcrypt

# Create configuration
cp config/backup.conf.template config/backup.conf
# Edit config/backup.conf with your settings
```

## Configuration

Edit `config/backup.conf` with your settings:

```bash
# Path to your Logseq graph
LOGSQL_GRAPH_PATH="/path/to/your/logseq/graph"

# GitHub repository URL (SSH format recommended)
GITHUB_REPO_URL="git@github.com:username/logseq-backup.git"

# GPG key ID or email
GPG_KEY_ID="your-gpg-key-id-or-email"
```

### Finding Your GPG Key ID

```bash
# List your GPG keys
gpg --list-keys

# Or list with more details
gpg --list-keys --keyid-format LONG
```

## Usage

### Manual Backup

```bash
# Run backup manually
./scripts/backup.sh
```

### Restore from Backup

```bash
# Restore to a new location
./scripts/restore.sh --target /path/to/restore/location

# Pull latest changes to existing repository
./scripts/restore.sh --pull-only
```

### Check Logs

```bash
# View recent backup logs
ls -la logs/
tail -f logs/backup-*.log
```

### Understanding Encrypted Repositories

When using git-remote-gcrypt:

1. **Unusual Dates in GitHub**: The GitHub interface may show commits with dates like "Dec 31, 2012" - this is normal and happens because the commit metadata is encrypted.

2. **"root-commit"** in logs refers to the first commit in a repository, not the root user.

3. **Viewing Encrypted Contents**: To view the contents of your encrypted repository:
   ```bash
   # Restore to a temporary location to view contents
   ./scripts/restore.sh --target /tmp/logseq-view
   
   # Then browse the files
   ls -la /tmp/logseq-view
   ```

## Automated Backups

The setup script configures a cron job for daily backups at midnight. To manage cron jobs:

```bash
# View current cron jobs
crontab -l

# Edit cron jobs
crontab -e

# Remove all cron jobs
crontab -r
```

## GitHub Repository Setup

1. Create a new GitHub repository (e.g., `logseq-backup`)
2. Make it private for additional security
3. Add the SSH repository URL to your configuration:
   ```
   git@github.com:username/logseq-backup.git
   ```
4. Make sure your SSH key is set up with GitHub (see troubleshooting section)

## GPG Key Management

### Generate a New GPG Key

```bash
# Generate a new key
gpg --full-generate-key

# Export your public key (for sharing)
gpg --export -a your-email@example.com > public-key.asc

# Export your private key (for backup)
gpg --export-secret-key -a your-email@example.com > private-key.asc
```

### Import GPG Key

```bash
# Import public key
gpg --import public-key.asc

# Import private key
gpg --import private-key.asc
```

## Troubleshooting

### Common Issues

1. **git-remote-gcrypt not found**
   ```bash
   sudo apt install git-remote-gcrypt
   ```

2. **GPG key not found**
   ```bash
   # Check available keys
   gpg --list-keys
   
   # Generate new key if needed
   gpg --full-generate-key
   ```

3. **Permission denied**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   ```

4. **GitHub authentication issues**
   - Ensure you have SSH keys set up for GitHub:
     ```bash
     # Generate SSH key if you don't have one
     ssh-keygen -t ed25519 -C "your-email@example.com"
     
     # Add key to SSH agent
     eval "$(ssh-agent -s)"
     ssh-add ~/.ssh/id_ed25519
     
     # Copy public key to clipboard (install xclip if needed)
     cat ~/.ssh/id_ed25519.pub
     # Then add to GitHub: Settings → SSH and GPG keys → New SSH key
     
     # Test connection
     ssh -T git@github.com
     ```

### Log Files

Check the logs directory for detailed error information:

```bash
# View recent logs
ls -la logs/

# Check specific log file
cat logs/backup-20240801-120000.log
```

### Testing

Test your setup:

```bash
# Test configuration
./scripts/setup.sh --test

# Test backup manually
./scripts/backup.sh

# Test restore
./scripts/restore.sh --target /tmp/test-restore
```

## Security Considerations

1. **Backup Your GPG Keys**: Store your GPG private key securely
2. **Repository Privacy**: Use private GitHub repositories
3. **Key Rotation**: Regularly rotate your GPG keys
4. **Access Control**: Limit access to your backup scripts and configuration

## File Structure

```
logseq-backup-solution/
├── scripts/
│   ├── backup.sh          # Main backup script
│   ├── restore.sh         # Restore script
│   └── setup.sh           # Setup script
├── config/
│   ├── backup.conf        # Configuration file
│   └── backup.conf.template
├── logs/                  # Backup logs
└── README.md             # This file
```

## Advanced Configuration

### Multiple GPG Keys

To use multiple GPG keys for collaboration:

```bash
# In backup.conf, separate multiple keys with spaces
GPG_KEY_ID="key1@example.com key2@example.com"
```

### Custom Backup Schedule

Edit the cron job for different schedules:

```bash
# Daily at 2 AM
0 2 * * * /path/to/backup.sh

# Every 6 hours
0 */6 * * * /path/to/backup.sh

# Weekly on Sunday at 1 AM
0 1 * * 0 /path/to/backup.sh
```

### Exclude Files from Backup

Edit the `.gitignore` file in your Logseq graph to exclude files:

```
# Example exclusions
*.tmp
*.log
.DS_Store
Thumbs.db
```

## Support

For issues and questions:
1. Check the logs in the `logs/` directory
2. Verify your configuration in `config/backup.conf`
3. Test with the setup script: `./scripts/setup.sh --test`

## License

This solution is provided as-is for educational and personal use.

## Credits

- [git-remote-gcrypt](https://github.com/spwhitton/git-remote-gcrypt) - The encryption layer
- [Logseq](https://logseq.com/) - The note-taking application 