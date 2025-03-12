#!/bin/bash
# Script to set up the test environment and run the tests
#
# This script manages the test environment for the RStudio directory management scripts.
# It can set up the Docker container, create test users, run tests, and clean up.
#
# For more information, see the README.md file in this directory.

set -e

# Source the test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_config.sh"

# Function to display usage information
show_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --setup-only     Only set up the test environment, don't run tests"
  echo "  --no-cleanup     Don't clean up test environment after running tests"
  echo "  --cleanup-only   Only clean up test environment, don't run tests"
  echo "  --coverage       Run tests with coverage report"
  echo "  -v, --verbose    Run tests with verbose output"
  echo "  --ssh-key PATH   Specify a custom SSH public key to use (default: ~/.ssh/id_rsa.pub)"
  echo "  --rebuild        Force rebuild of the Docker container"
  echo "  --help           Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0                       # Run all tests with default settings"
  echo "  $0 --verbose             # Run tests with verbose output"
  echo "  $0 --coverage            # Run tests with coverage report"
  echo "  $0 --setup-only          # Only set up the test environment"
  echo "  $0 --no-cleanup          # Run tests without cleaning up after"
  echo "  $0 --cleanup-only        # Only clean up the test environment"
  echo "  $0 --ssh-key ~/.ssh/id_ed25519.pub  # Use a specific SSH key"
  echo "  $0 --rebuild             # Force rebuild of the Docker container"
  echo "  $0 --verbose --coverage  # Run tests with verbose output and coverage"
}

# Display help message if no arguments are provided
if [ $# -eq 0 ]; then
  echo "Running tests with default settings."
  echo "Use --help for more options."
  echo ""
fi

# Parse command line arguments
SETUP_ONLY=false
CLEAN_ONLY=false
COVERAGE=false
VERBOSE=false
NO_CLEANUP=false
REBUILD=false
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup-only)
      SETUP_ONLY=true
      NO_CLEANUP=true  # Don't clean up if only setting up
      shift
      ;;
    --cleanup-only)
      CLEAN_ONLY=true
      shift
      ;;
    --no-cleanup)
      NO_CLEANUP=true
      shift
      ;;
    --coverage)
      COVERAGE=true
      shift
      ;;
    -v)
      VERBOSE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --ssh-key)
      SSH_KEY_PATH="$2"
      shift 2
      ;;
    --rebuild)
      REBUILD=true
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Function to clean up the test environment
cleanup_environment() {
  echo "Cleaning up test environment..."
  
  # Source the test utilities
  source "$SCRIPT_DIR/test_utils_combined.sh"
  
  # Stop and remove Docker container
  echo "Stopping and removing Docker container..."
  docker stop test-ssh-container 2>/dev/null || true
  docker rm test-ssh-container 2>/dev/null || true
  
  # Remove test user
  echo "Removing test user..."
  sudo userdel -r "$TEST_ACCOUNT" 2>/dev/null || true
  
  # Remove SSH config
  echo "Removing SSH configuration..."
  rm -rf /tmp/test-ssh-keys
  
  # Clean up environment variables
  cleanup_env_vars
  
  echo "Test environment cleanup complete."
}

# Set up trap to ensure cleanup on script exit, interrupt, or termination
cleanup_on_exit() {
  # Only clean up if NO_CLEANUP is false
  if [ "$NO_CLEANUP" = false ]; then
    echo "Caught exit signal. Cleaning up..."
    cleanup_environment
  fi
}

# Register the trap for various signals
trap cleanup_on_exit EXIT INT TERM

# Clean up if requested
if [ "$CLEAN_ONLY" = true ]; then
  cleanup_environment
  exit 0
fi

# Function to set up the test environment
setup_environment() {
  echo "Setting up test environment..."
  
  # Create test user
  echo "Creating test user..."
  source "$SCRIPT_DIR/test_utils_combined.sh"
  create_local_test_user
  
  # Copy SSH key if provided
  if [ -n "$SSH_KEY_PATH" ]; then
    echo "Using custom SSH key: $SSH_KEY_PATH"
    copy_ssh_key "$SSH_KEY_PATH"
  else
    # Use default SSH key
    echo "Using default SSH key"
    copy_ssh_key
  fi
  
  # Build and start Docker container
  echo "Building and starting Docker container..."
  
  # Check if container already exists
  if docker ps -a | grep -q test-ssh-container; then
    if [ "$REBUILD" = true ]; then
      echo "Removing existing container for rebuild..."
      docker rm -f test-ssh-container || true
    else
      echo "Container already exists, checking if it's running..."
      if docker ps | grep -q test-ssh-container; then
        echo "Container is already running."
      else
        echo "Container exists but is not running, starting it..."
        docker start test-ssh-container
      fi
      return 0
    fi
  fi
  
  # Build the Docker image
  echo "Building Docker image..."
  docker build -t test-ssh-server "$SCRIPT_DIR"
  
  # Run the container
  echo "Starting Docker container..."
  docker run -d --name test-ssh-container -p 2222:22 test-ssh-server
  
  # Wait for container to be ready
  echo "Waiting for container to be ready..."
  for i in {1..30}; do
    if docker logs test-ssh-container 2>&1 | grep -q "Container is ready"; then
      echo "Container is ready."
      break
    fi
    echo "Waiting for container to be ready... ($i/30)"
    sleep 1
  done
  
  # Set up SSH config
  echo "Setting up SSH configuration..."
  mkdir -p /tmp/test-ssh-keys
  
  # Copy SSH key from container
  echo "Copying SSH key from container..."
  for retry in {1..5}; do
    if docker exec test-ssh-container ls -la "/home/$TEST_ACCOUNT/.ssh/id_rsa" >/dev/null 2>&1; then
      echo "SSH key found in container, copying..."
      docker cp "test-ssh-container:/home/$TEST_ACCOUNT/.ssh/id_rsa" /tmp/test-ssh-keys/id_rsa && break
      echo "Failed to copy SSH key, retrying ($retry/5)..."
    else
      echo "SSH key not found in container, attempting to generate it..."
      docker exec test-ssh-container bash -c "
        mkdir -p /home/$TEST_ACCOUNT/.ssh
        chmod 700 /home/$TEST_ACCOUNT/.ssh
        ssh-keygen -t rsa -f /home/$TEST_ACCOUNT/.ssh/id_rsa -N ''
        cp /home/$TEST_ACCOUNT/.ssh/id_rsa.pub /home/$TEST_ACCOUNT/.ssh/authorized_keys
        chown -R $TEST_ACCOUNT:$TEST_ACCOUNT /home/$TEST_ACCOUNT/.ssh
        chmod 600 /home/$TEST_ACCOUNT/.ssh/authorized_keys
        chmod 600 /home/$TEST_ACCOUNT/.ssh/id_rsa
      "
      # Try to copy again
      if docker cp "test-ssh-container:/home/$TEST_ACCOUNT/.ssh/id_rsa" /tmp/test-ssh-keys/id_rsa; then
        echo "Successfully generated and copied SSH key"
        break
      fi
    fi
    
    if [ $retry -eq 5 ]; then
      echo "Failed to copy SSH key after 5 attempts, using a locally generated key instead"
      ssh-keygen -t rsa -f /tmp/test-ssh-keys/id_rsa -N ""
    else
      sleep 2
    fi
  done
  
  chmod 600 /tmp/test-ssh-keys/id_rsa
  
  # Create SSH config
  cat > /tmp/test-ssh-keys/config << EOF
Host 127.0.0.1
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    User $TEST_ACCOUNT
    IdentityFile /tmp/test-ssh-keys/id_rsa
    Port 2222
    LogLevel ERROR
EOF
  
  chmod 600 /tmp/test-ssh-keys/config
  
  # Set environment variable for tests
  export SSH_CONFIG_FILE="/tmp/test-ssh-keys/config"
  
  echo "Test environment setup complete."
}

# Set up test environment
setup_environment

# Exit if setup only
if [ "$SETUP_ONLY" = true ]; then
  echo "Test environment setup complete."
  exit 0
fi

# Run tests with coverage if requested
if [ "$COVERAGE" = true ]; then
  echo "Running tests with coverage..."
  
  # Source the coverage utilities
  source "$SCRIPT_DIR/test_coverage.sh"
  
  # Set environment variable for shell coverage
  export SHELL_COVERAGE=true
  
  # Run tests with coverage
  if [ "$VERBOSE" = true ]; then
    python -m pytest -v
  else
    python -m pytest
  fi
  
  # Generate coverage report
  generate_report
else
  # Run tests normally
  echo "Running tests..."
  if [ "$VERBOSE" = true ]; then
    python -m pytest -v
  else
    python -m pytest
  fi
fi

# Clean up unless --no-cleanup was specified
if [ "$NO_CLEANUP" = false ]; then
  # Only change to tests directory if not already there
  if [[ "$(basename "$(pwd)")" != "tests" ]]; then
    cd tests
  fi
  cleanup_environment
fi

echo "Tests completed."
exit 0 