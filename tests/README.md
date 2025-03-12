# Custom Script Testing Framework

A comprehensive testing framework for validating shell scripts using pytest and Docker.

## Overview

This testing framework provides an isolated environment for testing shell scripts safely and reliably. It uses Docker containers to create a controlled environment where scripts can be executed without affecting the host system, and pytest to organize and run the tests.

## Prerequisites

- Python 3.7+
- Docker
- Python packages:
  - pytest
  - docker
  - pytest-cov

## Installation

1. Install required Python packages:
   ```bash
   pip install pytest docker pytest-cov
   ```

2. Ensure Docker is running:
   ```bash
   docker info
   ```

## Test Environment

The testing framework creates a Docker container with the following:

- Base OS: Rocky Linux 8 (minimal)
- SSH server configured for key-based authentication
- Test user account (`ext_lastname_firstname_domain_com`)
- Simulated directory structure for testing file operations
- SSH key configuration for secure access

This isolated environment allows for safe testing of scripts without affecting the host system. The container is configured to:

1. Allow SSH connections from the host
2. Provide a realistic environment for script execution
3. Persist between test runs if needed (using the `--no-cleanup` option)

## Running Tests

The main script for running tests is `run_tests.sh`. It handles setting up the test environment, running the tests, and cleaning up afterward.

```bash
./run_tests.sh [OPTIONS]
```

### Options

- `--setup-only`: Only set up the test environment, don't run tests
- `--no-cleanup`: Don't clean up the test environment after tests
- `--rebuild`: Force rebuild of the Docker container
- `--coverage`: Generate coverage reports

### Examples

Run all tests:
```bash
./run_tests.sh
```

Set up the environment without running tests:
```bash
./run_tests.sh --setup-only
```

Run tests with coverage reporting:
```bash
./run_tests.sh --coverage
```

Run tests and keep the container for debugging:
```bash
./run_tests.sh --no-cleanup
```

Force rebuild of the container and run tests:
```bash
./run_tests.sh --rebuild
```

## Writing Tests

The test framework uses pytest for writing and running tests. The main test file is `test_custom_script.py`, which contains a simplified test for file creation in the Docker container.

### Example Test

```python
def test_file_creation_in_container(ssh_server, run_remote_command):
    """
    Test creating a file in the /tmp directory of the Docker container.
    
    This test:
    1. Checks that the file doesn't exist
    2. Runs the simple script to create the file
    3. Verifies the file was created
    4. Cleans up by removing the file
    """
    # Setup
    test_filename = "test_file_creation.txt"
    tmp_path = "/tmp/" + test_filename
    
    # Ensure file doesn't exist at start
    check_cmd = f"ls -la {tmp_path} 2>/dev/null || echo 'NOT_FOUND'"
    result = run_remote_command(check_cmd)
    assert "NOT_FOUND" in result, f"File {tmp_path} already exists before test"
    
    # Run the simple script to create the file
    cmd = f"./simple_script.sh --filename {test_filename} create"
    result = run_remote_command(cmd)
    
    # Verify file was created
    check_cmd = f"ls -la {tmp_path} 2>/dev/null || echo 'NOT_FOUND'"
    result = run_remote_command(check_cmd)
    assert "NOT_FOUND" not in result, f"File {tmp_path} was not created"
    
    # Cleanup - remove the file
    cleanup_cmd = f"rm -f {tmp_path}"
    run_remote_command(cleanup_cmd)
```

## Test Fixtures

The `conftest.py` file contains several fixtures that can be used in tests:

### Key Fixtures

- `docker_client`: Provides a Docker client for managing containers
- `container_name`: Returns the name of the test container
- `ssh_key_path`: Returns the path to the SSH private key
- `test_account`: Returns the username for the test account
- `ssh_server`: Provides SSH server connection details (IP and key path)
- `run_remote_command`: Function to run commands on the SSH server
- `run_script`: Function to run a script with proper environment
- `temp_file_creator`: Function to create temporary files with content
- `cleanup_all_test_accounts`: Cleans up test accounts at the end of the session

### Using Fixtures in Tests

To use these fixtures in your tests, simply include them as parameters in your test function:

```python
def test_example(ssh_server, run_remote_command, tmp_path):
    # Your test code here
    pass
```

## Directory Structure

```
tests/
├── conftest.py               # Test fixtures and configuration
├── container_management.sh   # Functions for managing Docker containers
├── Dockerfile                # Defines the test container
├── README.md                 # This documentation file
├── run_tests.sh              # Main script for running tests
├── test_config.sh            # Test configuration (usernames, paths, etc.)
├── test_coverage.sh          # Functions for generating coverage reports
├── test_custom_script.py     # Tests for the script template
├── test_utils_combined.sh    # Combined utility functions for tests
└── user_ssh_key.pub          # Public SSH key for testing
```

## Extending the Test Framework

To add new test functionality:

1. Add new test functions to `test_custom_script.py`
2. Add new fixtures to `conftest.py` if needed
3. Update the Docker container in `Dockerfile` if additional dependencies are required
4. Add new utility functions to the shell scripts if needed

### Adding New Tests

When adding new tests, follow these guidelines:

1. Each test should focus on a single functionality
2. Use descriptive test names that indicate what is being tested
3. Include docstrings that explain the purpose and steps of the test
4. Use the provided fixtures to interact with the Docker container
5. Clean up any resources created during the test

## Troubleshooting

Common issues and solutions:

- **Container build fails**: 
  - Ensure Docker is running and you have sufficient permissions
  - Check the Dockerfile for syntax errors
  - Verify network connectivity for downloading packages

- **SSH connection fails**: 
  - Check that the container is running (`docker ps`)
  - Verify SSH keys are properly configured
  - Ensure the SSH server is running in the container

- **Tests fail**: 
  - Verify that the simple script is executable and has the correct permissions
  - Check that the script is properly copied to the container
  - Look for error messages in the test output

- **Permission denied errors**:
  - Ensure the test user has appropriate permissions
  - Check file permissions in the container

## Coverage Reports

When running tests with the `--coverage` option, coverage reports will be generated in the `coverage` directory. These reports show which lines of code were executed during the tests.

### Viewing Coverage Reports

To view the coverage report:
```bash
cd coverage
python -m http.server
```

Then open a web browser and navigate to `http://localhost:8000`.

### Understanding Coverage Reports

The coverage report includes:

- **Line coverage**: Percentage of lines executed during tests
- **Branch coverage**: Percentage of code branches executed
- **File-by-file breakdown**: Coverage for each file
- **Highlighted source code**: Visual indication of covered and uncovered lines

Aim for high coverage (80%+) to ensure your scripts are thoroughly tested. 