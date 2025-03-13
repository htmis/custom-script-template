# Testing Utilities for Custom Script

This directory contains utilities for testing the custom script functionality in a controlled environment.

## Test Utilities

The main test utilities are contained in the following files:

- `test_utils.sh`: Utilities for user management, SSH key management, and container interaction
- `test_config.sh`: Configuration settings for test users, groups, and directories
- `container_management.sh`: Container startup and health check functionality
- `test_utils_test.sh`: Test script for testing the utilities in `test_utils.sh`

## Running the Tests

To test the utilities in `test_utils.sh`, you can run the `test_utils_test.sh` script:

```bash
./test_utils_test.sh
```

### Prerequisites

- Docker must be installed and running
- Sudo privileges are required for some tests (user creation)
- SSH client must be installed

### What the Tests Cover

The test script tests the following functionality:

1. Help function display
2. Environment variable cleanup
3. SSH key copying (both existing and non-existent keys)
4. Container status checking
5. Test environment setup (requires sudo)
6. Container command execution
7. File copying to and from the container

### Test Output

The test script will output the results of each test with colored indicators:
- ✓ Green: Test passed
- ✗ Red: Test failed
- Yellow: Test skipped or informational message

## Manual Testing

You can also manually test the utilities by sourcing the `test_utils.sh` file and calling the functions directly:

```bash
source tests/test_utils.sh
show_help
```

Available functions:

- `create_local_test_user`: Create test user on local system
- `copy_ssh_key [path]`: Copy SSH key for Docker container
- `connect_ssh`: Connect to the test container via SSH
- `check_status`: Check the status of the test container
- `run_in_container`: Run a command in the test container
- `copy_file`: Copy files to/from the test container
- `setup_test_environment`: Setup complete test environment
- `cleanup_env_vars`: Clean up environment variables

## Docker Container

The test environment uses a Docker container to simulate a remote system. The container is built from the `Dockerfile` in this directory and includes:

- SSH server
- Test user account
- Test groups

The container can be built and run manually:

```bash
# Build the container
docker build -t test-ssh-image tests/

# Run the container
docker run -d --name test-ssh-container -p 2222:22 test-ssh-image
```

You can then connect to the container via SSH:

```bash
ssh -p 2222 ext_lastname_firstname_domain_com@localhost
```

## Troubleshooting

If you encounter issues with the tests:

1. Check that Docker is installed and running
2. Ensure you have sudo privileges for user creation tests
3. Check that the SSH key generation is working correctly
4. Verify that port 2222 is not already in use on your system

For more detailed logs, you can check the Docker container logs:

```bash
docker logs test-ssh-container
``` 