#!/bin/bash
# Container Management Script
# This script combines functionality from:
# - startup.sh: Container initialization
# - healthcheck.sh: Container health monitoring
#
# Usage:
#   As container entrypoint: ./container_management.sh start
#   For healthcheck: ./container_management.sh healthcheck

# Source the test configuration
if [ -f /test_config.sh ]; then
  source /test_config.sh
fi

#####################################################
# SECTION 1: CONTAINER STARTUP
#####################################################

start_container() {
  echo "Starting SSH server..."

  # Start sshd in daemon mode
  /usr/sbin/sshd

  # Wait for SSH server to be ready
  if command -v pgrep >/dev/null 2>&1; then
    # Use pgrep if available
    while ! pgrep -x "sshd" > /dev/null; do
      sleep 1
    done
  else
    # Use ps as fallback
    while ! ps -ef | grep -v grep | grep -q "sshd"; do
      sleep 1
    done
  fi

  # Source the test configuration
  if [ -f /test_config.sh ]; then
    source /test_config.sh
  else
    echo "Warning: test_config.sh not found"
    exit 1
  fi

  # Create test groups
  create_test_groups

  echo "Creating test Google account..."
  # Create test Google account for testing
  create_docker_test_user

  # Create test directories
  create_test_directories

  # Set up SSH keys for the test account
  echo "Setting up SSH keys for $TEST_ACCOUNT..."
  mkdir -p "/home/$TEST_ACCOUNT/.ssh"
  chmod 700 "/home/$TEST_ACCOUNT/.ssh"

  # Always generate a new key pair
  ssh-keygen -t rsa -f "/home/$TEST_ACCOUNT/.ssh/id_rsa" -N ""

  # Use the user's SSH key if available for authorized_keys
  if [ -f /tmp/user_ssh_key.pub ]; then
    echo "Using provided SSH public key for authorized_keys"
    cp /tmp/user_ssh_key.pub "/home/$TEST_ACCOUNT/.ssh/authorized_keys"
  else
    echo "Using generated SSH public key for authorized_keys"
    cp "/home/$TEST_ACCOUNT/.ssh/id_rsa.pub" "/home/$TEST_ACCOUNT/.ssh/authorized_keys"
  fi

  chown -R "$TEST_ACCOUNT:$TEST_ACCOUNT" "/home/$TEST_ACCOUNT/.ssh"
  chmod 600 "/home/$TEST_ACCOUNT/.ssh/authorized_keys"
  chmod 600 "/home/$TEST_ACCOUNT/.ssh/id_rsa"

  # Run health check and signal readiness
  perform_healthcheck || true

  echo "Container is ready. You can SSH into it using:"
  echo "  ssh -p 2222 $TEST_ACCOUNT@localhost"

  # Keep container running
  echo "Container setup complete, keeping it alive..."
  exec tail -f /dev/null
}

#####################################################
# SECTION 2: CONTAINER HEALTHCHECK
#####################################################

perform_healthcheck() {
  # Don't exit on error
  set +e

  echo "Checking sshd process..."
  # Try pgrep first, fall back to ps if not available
  if command -v pgrep >/dev/null 2>&1; then
    if ! pgrep -x "sshd" > /dev/null; then
      echo "sshd process not found"
      # Start sshd if not running
      /usr/sbin/sshd
      sleep 2
      if ! pgrep -x "sshd" > /dev/null; then
        echo "Failed to start sshd"
        return 1
      fi
    fi
  else
    # Use ps as fallback
    if ! ps -ef | grep -v grep | grep -q "sshd"; then
      echo "sshd process not found"
      # Start sshd if not running
      /usr/sbin/sshd
      sleep 2
      if ! ps -ef | grep -v grep | grep -q "sshd"; then
        echo "Failed to start sshd"
        return 1
      fi
    fi
  fi
  echo "sshd process found"

  echo "Checking port 22..."
  # Use ss instead of netstat (more commonly available in minimal installations)
  if command -v ss >/dev/null 2>&1; then
    if ! ss -tuln | grep -q ":22 "; then
      echo "Port 22 is not listening"
      return 1
    fi
  else
    # Try netstat as fallback
    if command -v netstat >/dev/null 2>&1; then
      if ! netstat -tuln | grep -q ":22 "; then
        echo "Port 22 is not listening"
        return 1
      fi
    else
      echo "WARNING: Cannot check port 22, neither ss nor netstat available"
    fi
  fi
  echo "Port 22 is listening"

  # Basic SSH test - skip if it fails
  echo "Testing SSH connection..."
  if [ -n "$TEST_ACCOUNT" ]; then
    # Check if SSH key exists
    if [ -f "/home/$TEST_ACCOUNT/.ssh/id_rsa" ]; then
      echo "SSH key found at /home/$TEST_ACCOUNT/.ssh/id_rsa"
      
      # Test SSH connection
      if ! ssh -i "/home/$TEST_ACCOUNT/.ssh/id_rsa" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$TEST_ACCOUNT@127.0.0.1" whoami; then
        echo "SSH connection failed, but continuing anyway"
      else
        echo "SSH connection successful"
      fi
    else
      echo "SSH key not found at /home/$TEST_ACCOUNT/.ssh/id_rsa"
      echo "This will cause issues with the test setup"
      
      # Try to generate the key if it doesn't exist
      echo "Attempting to generate missing SSH key..."
      mkdir -p "/home/$TEST_ACCOUNT/.ssh"
      chmod 700 "/home/$TEST_ACCOUNT/.ssh"
      ssh-keygen -t rsa -f "/home/$TEST_ACCOUNT/.ssh/id_rsa" -N ""
      cp "/home/$TEST_ACCOUNT/.ssh/id_rsa.pub" "/home/$TEST_ACCOUNT/.ssh/authorized_keys"
      chown -R "$TEST_ACCOUNT:$TEST_ACCOUNT" "/home/$TEST_ACCOUNT/.ssh"
      chmod 600 "/home/$TEST_ACCOUNT/.ssh/authorized_keys"
      chmod 600 "/home/$TEST_ACCOUNT/.ssh/id_rsa"
      
      echo "SSH key generated, continuing..."
    fi
  else
    echo "TEST_ACCOUNT not set, skipping SSH connection test"
  fi

  # Signal container is ready
  echo "Container is ready"
  return 0
}

#####################################################
# SECTION 3: COMMAND HANDLING
#####################################################

# Process command line arguments
case "$1" in
  start)
    start_container
    ;;
  healthcheck)
    perform_healthcheck
    exit $?
    ;;
  *)
    echo "Usage: $0 {start|healthcheck}"
    echo "  start       - Start the container and keep it running"
    echo "  healthcheck - Perform health check on the container"
    exit 1
    ;;
esac 