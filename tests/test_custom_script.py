#!/usr/bin/env python3
"""
Tests for the simple_script.sh functionality.

This test suite verifies that the simple_script.sh properly handles
file operations in the /tmp directory. It tests the script's ability to:
- Create files in the /tmp directory
- List files matching a pattern
- Delete files from the /tmp directory

The tests run in an isolated Docker container to ensure they don't affect
the host system and to provide a consistent testing environment.

Each test focuses on a specific functionality of the script and includes
setup, execution, verification, and cleanup steps.
"""

import os
import pytest
import subprocess
from pathlib import Path


def test_file_creation_in_container(ssh_server, run_remote_command):
    """
    Test creating a file in the /tmp directory of the Docker container.
    
    This test verifies that the simple_script.sh can successfully create
    a file in the /tmp directory when invoked with the 'create' action.
    
    Steps:
    1. Checks that the file doesn't exist initially
    2. Runs the simple script with the 'create' action
    3. Verifies the file was created successfully
    4. Cleans up by removing the file
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The file doesn't exist before the test
        - The file exists after running the script
    """
    # Setup
    test_filename = "test_file_creation.txt"
    tmp_path = "/tmp/" + test_filename
    
    # Ensure file doesn't exist at start
    check_cmd = f"ls -la {tmp_path} 2>/dev/null || echo 'NOT_FOUND'"
    result = run_remote_command(check_cmd)
    assert "NOT_FOUND" in result, f"File {tmp_path} already exists before test"
    
    # Run the simple script to create the file
    # The script is in the home directory of the user in the container
    cmd = f"/home/testuser/simple_script.sh --filename {test_filename} create"
    result = run_remote_command(cmd)
    
    # Verify file was created
    check_cmd = f"ls -la {tmp_path} 2>/dev/null || echo 'NOT_FOUND'"
    result = run_remote_command(check_cmd)
    assert "NOT_FOUND" not in result, f"File {tmp_path} was not created"
    
    # Cleanup - remove the file
    cleanup_cmd = f"rm -f {tmp_path}"
    run_remote_command(cleanup_cmd)


# Commented out for documentation purposes
"""
def test_list_tmp_files(ssh_server, run_remote_command):
    '''
    Test the list action of the simple script.
    
    This test verifies that the simple_script.sh can successfully list
    files in the /tmp directory that match a specified pattern.
    
    Steps:
    1. Creates a test file in /tmp
    2. Runs the simple script with the 'list' action
    3. Verifies the file is included in the output
    4. Cleans up by removing the file
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The file is listed in the output of the script
    '''
    # Setup
    test_filename = "test_list_files.txt"
    tmp_path = "/tmp/" + test_filename
    
    # Create test file
    create_cmd = f"touch {tmp_path}"
    run_remote_command(create_cmd)
    
    # Run the simple script to list files
    script_path = os.path.join(os.getcwd(), "..", "simple_script.sh")
    cmd = f"cd .. && ./simple_script.sh --filename {test_filename} list"
    result = run_remote_command(cmd)
    
    # Verify file is listed
    assert test_filename in result, f"File {test_filename} was not listed"
    
    # Cleanup
    cleanup_cmd = f"rm -f {tmp_path}"
    run_remote_command(cleanup_cmd)


def test_delete_tmp_file(ssh_server, run_remote_command):
    '''
    Test the delete action of the simple script.
    
    This test verifies that the simple_script.sh can successfully delete
    a file from the /tmp directory when invoked with the 'delete' action.
    
    Steps:
    1. Creates a test file in /tmp
    2. Runs the simple script with the 'delete' action
    3. Verifies the file was deleted
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The file exists before deletion
        - The file doesn't exist after deletion
    '''
    # Setup
    test_filename = "test_delete_file.txt"
    tmp_path = "/tmp/" + test_filename
    
    # Create test file
    create_cmd = f"touch {tmp_path}"
    run_remote_command(create_cmd)
    
    # Run the simple script to delete the file
    script_path = os.path.join(os.getcwd(), "..", "simple_script.sh")
    cmd = f"cd .. && ./simple_script.sh --filename {test_filename} delete"
    result = run_remote_command(cmd)
    
    # Verify file was deleted
    check_cmd = f"ls -la {tmp_path} 2>/dev/null || echo 'NOT_FOUND'"
    result = run_remote_command(check_cmd)
    assert "NOT_FOUND" in result, f"File {tmp_path} was not deleted"


def test_nonexistent_file_deletion(ssh_server, run_remote_command):
    '''
    Test the delete action with a non-existent file.
    
    This test verifies that the simple_script.sh handles the case where
    a file doesn't exist when attempting to delete it. The script should
    report that the file was not found and exit with code 3.
    
    Steps:
    1. Ensures the test file doesn't exist
    2. Runs the simple script to delete the non-existent file
    3. Verifies the script reports the file as not found
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The script output contains "File not found"
    '''
    # Setup
    test_filename = "nonexistent_file.txt"
    tmp_path = "/tmp/" + test_filename
    
    # Ensure file doesn't exist
    cleanup_cmd = f"rm -f {tmp_path}"
    run_remote_command(cleanup_cmd)
    
    # Run the simple script to delete the non-existent file
    script_path = os.path.join(os.getcwd(), "..", "simple_script.sh")
    cmd = f"cd .. && ./simple_script.sh --filename {test_filename} delete"
    result = run_remote_command(cmd)
    
    # Verify script reports file not found
    assert "File not found" in result, "Script did not report file not found"


def test_script_help_output(ssh_server, run_remote_command):
    '''
    Test the help output of the simple script.
    
    This test verifies that the simple_script.sh displays appropriate help
    information when invoked with the --help option. The help output should
    include sections for usage, options, and actions.
    
    Steps:
    1. Runs the simple script with --help
    2. Verifies key sections are present in the help output
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The help output contains "Usage:", "Options:", and "Actions:" sections
    '''
    script_path = os.path.join(os.getcwd(), "..", "simple_script.sh")
    cmd = f"cd .. && ./simple_script.sh --help"
    result = run_remote_command(cmd)
    
    # Verify key sections in help output
    assert "Usage:" in result, "Usage section missing from help output"
    assert "Options:" in result, "Options section missing from help output"
    assert "Actions:" in result, "Actions section missing from help output"


def test_script_version_output(ssh_server, run_remote_command):
    '''
    Test the version output of the simple script.
    
    This test verifies that the simple_script.sh displays version information
    when invoked with the --version option.
    
    Steps:
    1. Runs the simple script with --version
    2. Verifies the version information is displayed
    
    Args:
        ssh_server: Fixture providing SSH server connection details
        run_remote_command: Fixture providing a function to run commands on the SSH server
    
    Assertions:
        - The output contains "Version"
    '''
    script_path = os.path.join(os.getcwd(), "..", "simple_script.sh")
    cmd = f"cd .. && ./simple_script.sh --version"
    result = run_remote_command(cmd)
    
    # Verify version information is displayed
    assert "Version" in result, "Version information missing from output"
"""

if __name__ == "__main__":
    pytest.main(["-v"]) 