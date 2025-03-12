#!/bin/bash
# Combined Test Utilities
# This script combines functionality from:
# - test_utils.sh: General test utilities
# - create_test_users.sh: User creation
# - copy_ssh_key.sh: SSH key management
#
# Usage:
#   source test_utils_combined.sh
#   Or run directly for help: ./test_utils_combined.sh

# Source the test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_config.sh"

#####################################################
# SECTION 1: USER MANAGEMENT
#####################################################

# Function to create test users on the host system
create_local_test_user() {
  echo "Creating test account: $TEST_ACCOUNT"
  sudo useradd -m -s /bin/bash "$TEST_ACCOUNT" 2>/dev/null || true
  echo "Test account setup complete."
}

#####################################################
# SECTION 2: SSH KEY MANAGEMENT
#####################################################

# Function to copy the user's SSH public key for use in the Docker container
copy_ssh_key() {
  # Default location for SSH public key
  DEFAULT_KEY_PATH="$HOME/.ssh/id_rsa.pub"
  KEY_PATH=${1:-$DEFAULT_KEY_PATH}

  # Check if the key exists
  if [ ! -f "$KEY_PATH" ]; then
    echo "Error: SSH public key not found at $KEY_PATH"
    echo "Usage: copy_ssh_key [path_to_public_key]"
    echo "Default path is $DEFAULT_KEY_PATH"
    return 1
  fi

  # Copy the key to the tests directory
  cp "$KEY_PATH" "$SCRIPT_DIR/user_ssh_key.pub"

  echo "SSH public key copied successfully to $SCRIPT_DIR/user_ssh_key.pub"
  echo "This key will be used when building the Docker container."
  echo "You can now run the tests or build the container."
}

#####################################################
# SECTION 3: CONTAINER INTERACTION
#####################################################

# Function to connect to the test container via SSH
connect_ssh() {
  echo "Connecting to test container via SSH..."
  
  # Create temporary SSH key
  TMP_KEY="/tmp/test_id_rsa"
  docker cp "test-ssh-container:/home/$TEST_ACCOUNT/.ssh/id_rsa" $TMP_KEY
  chmod 600 $TMP_KEY
  
  # Connect
  ssh -i $TMP_KEY -p 2222 $TEST_ACCOUNT@localhost
  
  # Clean up
  rm -f $TMP_KEY
}

# Function to check container status
check_status() {
  echo "Checking test container status..."
  
  if docker ps | grep -q test-ssh-container; then
    echo "Container is running."
    docker ps | grep test-ssh-container
    
    # Check container logs
    echo ""
    echo "Last 10 log lines:"
    docker logs --tail 10 test-ssh-container
  else
    echo "Container is not running."
    
    if docker ps -a | grep -q test-ssh-container; then
      echo "Container exists but is not running."
      docker ps -a | grep test-ssh-container
    else
      echo "Container does not exist."
    fi
  fi
}

# Function to run a command in the container
run_in_container() {
  if [ $# -eq 0 ]; then
    echo "Usage: run_in_container <command>"
    return 1
  fi
  
  echo "Running command in container: $@"
  docker exec -it test-ssh-container $@
}

# Function to copy files to/from the container
copy_file() {
  if [ $# -lt 2 ]; then
    echo "Usage: copy_file <source> <destination>"
    echo "Examples:"
    echo "  copy_file local_file.txt container:/path/to/dest"
    echo "  copy_file container:/path/to/file local_dest.txt"
    return 1
  fi
  
  source=$1
  dest=$2
  
  if [[ $source == container:* ]]; then
    # Copy from container to local
    container_path=${source#container:}
    echo "Copying from container:$container_path to $dest"
    docker cp test-ssh-container:$container_path $dest
  elif [[ $dest == container:* ]]; then
    # Copy from local to container
    container_path=${dest#container:}
    echo "Copying from $source to container:$container_path"
    docker cp $source test-ssh-container:$container_path
  else
    echo "Error: Either source or destination must start with 'container:'"
    return 1
  fi
}

#####################################################
# SECTION 4: SETUP HELPERS
#####################################################

# Function to setup the complete test environment
setup_test_environment() {
  # Create local test user
  create_local_test_user
  
  # Copy SSH key if provided
  if [ -n "$1" ]; then
    copy_ssh_key "$1"
  fi
  
  echo "Test environment setup complete."
  echo "You can now build and run the Docker container."
}

# Function to clean up environment variables
cleanup_env_vars() {
  echo "Cleaning up environment variables..."
  
  # Unset environment variables
  unset SSH_CONFIG_FILE
  unset SHELL_COVERAGE
  
  # Unset test configuration variables
  unset TEST_ACCOUNT
  unset TEST_GROUP
  unset RESEARCH_QHS_DIR
  unset RESEARCH_LABS_DIR
  unset FSLUSTRE_QHS_DIR
  unset FSLUSTRE_LABS_DIR
  
  # Unset function exports
  if declare -F | grep -q "run_with_coverage"; then
    unset -f run_with_coverage
  fi
  if declare -F | grep -q "generate_shell_report"; then
    unset -f generate_shell_report
  fi
  if declare -F | grep -q "run_python_coverage"; then
    unset -f run_python_coverage
  fi
  if declare -F | grep -q "generate_report"; then
    unset -f generate_report
  fi
  if declare -F | grep -q "clean_coverage"; then
    unset -f clean_coverage
  fi
  
  echo "Environment variables cleanup complete."
}

# Function to show help
show_help() {
  echo "Combined Test Utilities"
  echo "======================"
  echo ""
  echo "This script provides utility functions for working with the test environment."
  echo ""
  echo "Test Account: $TEST_ACCOUNT"
  echo ""
  echo "Available functions:"
  echo "  create_local_test_user  - Create test user on local system"
  echo "  copy_ssh_key [path]     - Copy SSH key for Docker container"
  echo "  connect_ssh             - Connect to the test container via SSH"
  echo "  check_status            - Check the status of the test container"
  echo "  run_in_container        - Run a command in the test container"
  echo "  copy_file               - Copy files to/from the test container"
  echo "  setup_test_environment  - Setup complete test environment"
  echo "  cleanup_env_vars        - Clean up environment variables"
  echo ""
  echo "Usage:"
  echo "  source test_utils_combined.sh"
  echo "  create_local_test_user"
  echo "  copy_ssh_key ~/.ssh/id_rsa.pub"
  echo "  connect_ssh"
  echo "  check_status"
  echo "  run_in_container ls -la /research"
  echo "  copy_file local_file.txt container:/tmp/"
  echo "  copy_file container:/etc/passwd local_passwd.txt"
  echo "  setup_test_environment [ssh_key_path]"
  echo "  cleanup_env_vars"
}

# If script is executed directly, show help or run command if provided
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [ $# -eq 0 ]; then
    show_help
  else
    # Execute the specified function
    "$@"
  fi
else
  echo "Combined test utilities loaded. Use 'show_help' to see available functions."
fi

# Export functions for use in other scripts
export -f cleanup_env_vars 