#!/bin/bash
# Central configuration file for test users and groups
# This file defines the test users, groups, and directories used in tests

# Test account name - used across all test scripts
export TEST_ACCOUNT="testuser"

# Test groups
export TEST_GROUP="mcc_live_hpc_posix_stats_inform"

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
    
    # Create user's home directory if it doesn't exist
    if [ ! -d "/home/$username" ]; then
        mkdir -p "/home/$username"
        chown "$username:$username" "/home/$username"
        chmod 750 "/home/$username"
    fi
    
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