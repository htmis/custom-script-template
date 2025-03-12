#!/bin/bash
# Central configuration file for test users and groups
# This file defines the test users, groups, and directories used in tests

# Test account name - used across all test scripts
export TEST_ACCOUNT="ext_lastname_firstname_domain_com"

# Test groups
export TEST_GROUP="mcc_live_hpc_posix_stats_inform"

# Test directories
export RESEARCH_QHS_DIR="/research/qhs"
export RESEARCH_LABS_DIR="/research/labs"
export FSLUSTRE_QHS_DIR="/fslustre/qhs"
export FSLUSTRE_LABS_DIR="/fslustre/labs"

# Function to create test user on host system
create_test_user() {
    local username="${1:-$TEST_ACCOUNT}"
    echo "Creating test account: $username"
    sudo useradd -m -s /bin/bash "$username" 2>/dev/null || true
    echo "Test account setup complete."
}

# Function to create test user in Docker container
create_docker_test_user() {
    local username="${1:-$TEST_ACCOUNT}"
    echo "Creating test account in Docker: $username"
    useradd -m -s /bin/bash "$username" 2>/dev/null || true
    echo "$username:password" | chpasswd
    
    # Add user to sudoers with NOPASSWD
    echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Setup SSH keys will be done in startup.sh
    echo "Docker test account setup complete."
}

# Function to create test groups
create_test_groups() {
    echo "Creating test groups..."
    groupadd "$TEST_GROUP" 2>/dev/null || true
    echo "Test groups created."
}

# Function to create test directories
create_test_directories() {
    local username="${1:-$TEST_ACCOUNT}"
    echo "Creating test directories for: $username"
    
    # Create directories
    mkdir -p "$RESEARCH_QHS_DIR/$username"
    mkdir -p "$RESEARCH_LABS_DIR/$username"
    mkdir -p "$FSLUSTRE_QHS_DIR/$username"
    mkdir -p "$FSLUSTRE_LABS_DIR/$username"
    
    # Set ownership
    chown "$username:$TEST_GROUP" "$RESEARCH_QHS_DIR/$username"
    chown "$username:$username" "$RESEARCH_LABS_DIR/$username"
    chown "$username:$username" "$FSLUSTRE_QHS_DIR/$username"
    chown "$username:$username" "$FSLUSTRE_LABS_DIR/$username"
    
    # Set permissions
    chmod 750 "$RESEARCH_QHS_DIR/$username"
    chmod 750 "$RESEARCH_LABS_DIR/$username"
    chmod 750 "$FSLUSTRE_QHS_DIR/$username"
    chmod 750 "$FSLUSTRE_LABS_DIR/$username"
    
    echo "Test directories created."
}

# Function to clean up test user
cleanup_test_user() {
    local username="${1:-$TEST_ACCOUNT}"
    echo "Removing test user: $username"
    sudo userdel -r "$username" 2>/dev/null || true
    
    # Double check home directory is removed
    if [ -d "/home/$username" ]; then
        echo "Forcibly removing test user home directory..."
        sudo rm -rf "/home/$username"
    fi
    
    echo "Test user cleanup complete."
} 