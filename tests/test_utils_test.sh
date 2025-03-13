#!/bin/bash
# Test script for test_utils.sh
# This script tests the functionality of the utilities in test_utils.sh
#
# Usage:
#   ./test_utils_test.sh

# Set up error handling
set -e
trap 'echo "Error on line $LINENO"; exit 1' ERR

# Source the test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to run a test and report results
run_test() {
  local test_name="$1"
  local test_cmd="$2"
  
  echo -e "${YELLOW}Running test: ${test_name}${NC}"
  
  # Run the test command
  if eval "$test_cmd"; then
    echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
    return 0
  else
    echo -e "${RED}✗ Test failed: ${test_name}${NC}"
    return 1
  fi
}

# Function to check if Docker is installed and running
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker to run these tests.${NC}"
    exit 1
  fi
  
  if ! docker info &> /dev/null; then
    echo -e "${RED}Docker daemon is not running. Please start Docker to run these tests.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Docker is installed and running.${NC}"
}

# Main test function
main() {
  echo "Starting tests for test_utils.sh"
  
  # Check if Docker is installed and running
  check_docker
  
  # Test 1: Test show_help function
  run_test "Show Help" "show_help | grep -q 'Test Utilities'"
  
  # Test 2: Test cleanup_env_vars function
  run_test "Cleanup Environment Variables" "cleanup_env_vars && echo 'Cleanup successful'"
  
  # Test 3: Test copy_ssh_key function with non-existent key
  run_test "Copy SSH Key (Non-existent)" "! copy_ssh_key /nonexistent/key.pub"
  
  # Test 4: Test copy_ssh_key function with existing key
  # First create a temporary SSH key for testing
  mkdir -p /tmp/test_ssh
  ssh-keygen -t rsa -f /tmp/test_ssh/id_rsa -N "" -q
  run_test "Copy SSH Key (Existing)" "copy_ssh_key /tmp/test_ssh/id_rsa.pub"
  
  # Test 5: Test check_status function
  run_test "Check Container Status" "check_status | grep -q 'Container is\\|is not'"
  
  # Test 6: Test setup_test_environment function
  # Note: This requires sudo privileges
  if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
    run_test "Setup Test Environment" "setup_test_environment /tmp/test_ssh/id_rsa.pub"
  else
    echo -e "${YELLOW}Skipping setup_test_environment test - requires sudo privileges${NC}"
  fi
  
  # Test 7: Test container management
  # Build the Docker container if it doesn't exist
  if ! docker images | grep -q test-ssh-image; then
    echo "Building Docker container for testing..."
    docker build -t test-ssh-image "$SCRIPT_DIR"
  fi
  
  # Start the container if it's not already running
  if ! docker ps | grep -q test-ssh-container; then
    echo "Starting Docker container for testing..."
    docker run -d --name test-ssh-container -p 2222:22 test-ssh-image
    # Wait for container to be ready
    sleep 5
  fi
  
  # Test run_in_container function
  run_test "Run Command in Container" "run_in_container ls -la /home | grep -q '$TEST_ACCOUNT'"
  
  # Test copy_file function
  echo "test content" > /tmp/test_file.txt
  run_test "Copy File to Container" "copy_file /tmp/test_file.txt container:/tmp/test_file.txt"
  run_test "Copy File from Container" "copy_file container:/tmp/test_file.txt /tmp/test_file_from_container.txt && grep -q 'test content' /tmp/test_file_from_container.txt"
  
  # Clean up
  echo "Cleaning up test files..."
  rm -f /tmp/test_file.txt /tmp/test_file_from_container.txt
  rm -rf /tmp/test_ssh
  
  # Stop and remove the container
  echo "Stopping and removing Docker container..."
  docker stop test-ssh-container || true
  docker rm test-ssh-container || true
  
  echo "All tests completed."
}

# Run the tests
main "$@" 