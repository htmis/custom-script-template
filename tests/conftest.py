"""
Pytest configuration and fixtures for custom script testing.

This module provides fixtures for testing shell scripts in an isolated Docker environment.
It includes fixtures for:
- Setting up and managing Docker containers
- Establishing SSH connections to the container
- Running commands in the container
- Creating and managing test files
- Cleaning up resources after tests

The fixtures in this file are designed to work together to provide a comprehensive
testing environment for shell scripts, allowing them to be tested in isolation
without affecting the host system.

Usage:
    Import fixtures directly in test files:
    ```python
    def test_example(ssh_server, run_remote_command):
        # Test code here
        pass
    ```
"""

import os
import time
import pytest
import subprocess
import socket
import docker
from pathlib import Path


@pytest.fixture(scope="session")
def docker_client():
    """
    Provides a Docker client for managing containers.
    
    Returns:
        docker.DockerClient: Initialized Docker client
    """
    try:
        client = docker.from_env()
        # Test connection
        client.ping()
        return client
    except Exception as e:
        pytest.fail(f"Failed to connect to Docker: {e}")


@pytest.fixture(scope="session")
def container_name():
    """
    Returns the name of the test container.
    
    Returns:
        str: Container name
    """
    return os.environ.get("TEST_CONTAINER_NAME", "test-ssh-container")


@pytest.fixture(scope="session")
def ssh_key_path():
    """
    Returns the path to the SSH private key for connecting to the test container.
    
    Returns:
        str: Path to the SSH private key file
    """
    # Create the directory if it doesn't exist
    os.makedirs("/tmp/test-ssh-keys", exist_ok=True)
    
    # Use the user's SSH key if available
    user_ssh_key = os.path.expanduser("~/.ssh/id_rsa")
    if os.path.exists(user_ssh_key):
        return user_ssh_key
    
    # Otherwise, use the default path
    path = os.environ.get("SSH_KEY_PATH", "/tmp/test-ssh-keys/id_rsa")
    if not os.path.exists(path):
        # If the key doesn't exist, create a warning but don't fail
        print(f"WARNING: SSH key not found at {path}. Some tests may fail.")
    
    return path


@pytest.fixture(scope="session")
def test_account():
    """
    Returns the username for the test account in the container.
    
    Returns:
        str: Test account username
    """
    return os.environ.get("TEST_ACCOUNT", "testuser")


@pytest.fixture(scope="session")
def ssh_server(docker_client, container_name, ssh_key_path):
    """
    Provides the SSH server connection details.
    
    This fixture verifies that the SSH server is running and accessible
    before returning its connection details.
    
    Args:
        docker_client: Docker client instance
        container_name: Name of the test container
        ssh_key_path: Path to the SSH private key
        
    Returns:
        tuple: (server_ip, ssh_key_path) - IP address and path to the SSH key
    """
    # Get the container
    try:
        container = docker_client.containers.get(container_name)
        if container.status != "running":
            pytest.fail(f"Container {container_name} is not running")
    except docker.errors.NotFound:
        pytest.fail(f"Container {container_name} not found. Run setup script first.")
    
    # Get the container IP
    container_ip = container.attrs["NetworkSettings"]["IPAddress"]
    if not container_ip:
        # Try to get IP from bridge network
        networks = container.attrs["NetworkSettings"]["Networks"]
        if "bridge" in networks:
            container_ip = networks["bridge"]["IPAddress"]
    
    if not container_ip:
        # If we still don't have an IP, use localhost with the mapped port
        container_ip = "localhost"
    
    # Use the correct username
    username = "ext_lastname_firstname_domain_com"
    
    # Wait for SSH to be available
    max_retries = 10
    retry_delay = 1
    
    for i in range(max_retries):
        try:
            if container_ip == "localhost":
                # For localhost, check if the mapped port is open
                host_port = 2222  # Default mapped port
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex((container_ip, host_port))
                sock.close()
            else:
                # For container IP, check if the SSH port is open
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex((container_ip, 22))
                sock.close()
            
            if result == 0:
                # SSH port is open, now test authentication
                cmd = [
                    "ssh",
                    "-i", ssh_key_path,
                    "-o", "StrictHostKeyChecking=no",
                    "-o", "UserKnownHostsFile=/dev/null",
                    "-o", "BatchMode=yes",
                    "-o", "ConnectTimeout=5"
                ]
                
                if container_ip == "localhost":
                    cmd.append("-p")
                    cmd.append(str(host_port))
                
                cmd.append(f"{username}@{container_ip}")
                cmd.append("echo SSH connection successful")
                
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if proc.returncode == 0:
                    return container_ip, ssh_key_path
                else:
                    if i == max_retries - 1:
                        pytest.fail(f"SSH authentication failed: {proc.stderr}")
            else:
                if i == max_retries - 1:
                    pytest.fail(f"SSH port not open on {container_ip}")
        except Exception as e:
            if i == max_retries - 1:
                pytest.fail(f"Error connecting to SSH server: {str(e)}")
        
        # Wait before retrying
        time.sleep(retry_delay)
    
    # If we get here, we've exhausted all retries
    pytest.fail("Failed to connect to SSH server after multiple attempts")


@pytest.fixture
def run_remote_command(ssh_server):
    """
    Fixture to run a command on the remote SSH server.
    
    Args:
        ssh_server: Fixture that provides SSH server connection details
        
    Returns:
        Function to run commands on the SSH server
    """
    server_ip, ssh_key_path = ssh_server
    
    def _run_command(command):
        """
        Run a command on the remote SSH server.
        
        Args:
            command: Command to run
            
        Returns:
            Output of the command
        """
        ssh_cmd = [
            "ssh",
            "-i", ssh_key_path,
            "-o", "StrictHostKeyChecking=no",
            f"ext_lastname_firstname_domain_com@{server_ip}"
        ]
        
        # If connecting to localhost, use port 2222, otherwise use default port 22
        if server_ip == "localhost":
            ssh_cmd.extend(["-p", "2222"])
        
        ssh_cmd.append(command)
        
        result = subprocess.run(
            ssh_cmd,
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode != 0 and result.stderr:
            print(f"SSH command failed: {result.stderr}")
            
        return result.stdout
    
    return _run_command


@pytest.fixture
def run_script():
    """
    Fixture that provides a function to run a script with proper environment.
    
    Returns:
        function: Function to run scripts
    """
    def _run_script(script_path, *args, env=None):
        """
        Run a script with the given arguments and environment.
        
        Args:
            script_path (str): Path to the script to run
            *args: Arguments to pass to the script
            env (dict, optional): Environment variables to set. Defaults to None.
            
        Returns:
            subprocess.CompletedProcess: Result of the script execution
        """
        cmd = [script_path]
        cmd.extend(args)
        
        # Combine environment variables
        combined_env = os.environ.copy()
        if env:
            combined_env.update(env)
        
        return subprocess.run(
            cmd,
            env=combined_env,
            capture_output=True,
            text=True
        )
    
    return _run_script


@pytest.fixture
def temp_file_creator(tmp_path):
    """
    Fixture that provides a function to create temporary files with content.
    
    Args:
        tmp_path: Pytest fixture providing a temporary directory
        
    Returns:
        function: Function to create temporary files
    """
    def _create_file(filename, content):
        """
        Create a temporary file with the given content.
        
        Args:
            filename (str): Name of the file to create
            content (str): Content to write to the file
            
        Returns:
            Path: Path to the created file
        """
        file_path = tmp_path / filename
        file_path.write_text(content)
        return file_path
    
    return _create_file


@pytest.fixture(scope="session", autouse=True)
def cleanup_all_test_accounts():
    """
    Fixture to clean up test accounts and directories at the end of the test session.
    
    This fixture runs automatically at the end of the test session to ensure
    that all test accounts and directories are removed.
    """
    # Yield control to the tests
    yield
    
    # Clean up at the end of the session
    test_account = os.environ.get("TEST_ACCOUNT", "testuser")
    
    # Clean up the test account
    try:
        subprocess.run(["sudo", "userdel", "-r", test_account], check=False)
    except Exception:
        pass 