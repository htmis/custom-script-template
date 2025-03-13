# Custom Script Template

A reusable template for creating custom shell scripts with standardized command-line argument handling, logging, and error handling.

## Overview

This template provides a foundation for creating well-structured shell scripts that follow best practices. It includes:

- Standardized command-line argument parsing
- File operation capabilities in the `/tmp` directory
- Error handling with appropriate exit codes
- Comprehensive documentation

## Template Functionality

The template script demonstrates basic file operations in `/tmp`:

- **Create**: Create a new file in the `/tmp` directory
- **List**: List files in `/tmp` matching a pattern
- **Delete**: Delete a specified file from the `/tmp` directory

## Available Scripts

This package includes two script templates:

1. **simple_script.sh**: A lightweight script focused on basic functionality
2. **custom_script.sh**: A more comprehensive template with advanced features like logging and dry-run mode

### Simple Script (simple_script.sh)

The simple script provides basic file operations with minimal dependencies.

```bash
./simple_script.sh [OPTIONS] ACTION
```

#### Options

- `-h, --help`: Display help message and exit
- `-f, --filename NAME`: Specify the filename to create/list/delete in `/tmp`
- `--version`: Display version information and exit

### Comprehensive Script (custom_script.sh)

The comprehensive script includes additional features like logging, dry-run mode, and output redirection.

```bash
./custom_script.sh [OPTIONS] ACTION
```

#### Options

- `-h, --help`: Display help message and exit
- `-v, --verbose`: Enable verbose output
- `-o, --output FILE`: Write output to FILE
- `-d, --dry-run`: Run script without making any actual changes
- `-f, --filename NAME`: Specify the filename to create/list/delete in `/tmp`
- `--version`: Display version information and exit

### Actions (Both Scripts)

- `create`: Create a new file in `/tmp` with the specified name
- `list`: List files in `/tmp` matching pattern
- `delete`: Delete the specified file from `/tmp`

### Examples

Create a file:
```bash
./simple_script.sh --filename test.txt create
```

List files matching a pattern:
```bash
./simple_script.sh --filename "test*" list
```

Delete a file:
```bash
./simple_script.sh --filename test.txt delete
```

## Testing

The template includes a comprehensive testing framework using pytest and Docker. This allows you to test your scripts in an isolated environment without affecting your host system.

### Running the Main Tests

To run the main tests:

```bash
cd tests
./run_tests.sh
```

Available options for the test runner:

```bash
./run_tests.sh [--setup-only] [--no-cleanup] [--rebuild] [--coverage]
```

### Testing Utilities

The template also includes utilities for testing in a Docker container environment:

- **test_utils.sh**: Utilities for user management, SSH key management, and container interaction
- **test_utils_test.sh**: Test script for testing the utilities in `test_utils.sh`

To test these utilities:

```bash
cd tests
./test_utils_test.sh
```

This will test:
- SSH key management
- Container status checking
- Test environment setup
- Container command execution
- File copying to and from the container

For more information about testing, see:
- [tests/README.md](tests/README.md) - General testing information
- [tests/README_test_utils.md](tests/README_test_utils.md) - Information about test utilities

## Customization Guide

To adapt this template for your own scripts:

1. Choose the appropriate template (simple_script.sh or custom_script.sh)
2. Copy the template file to a new location
3. Modify the script description and usage information
4. Update the action implementations to match your requirements
5. Add any additional functions needed for your specific use case
6. Update the tests to verify your script's functionality

## Best Practices

When customizing this template, consider the following best practices:

1. **Maintain Modularity**: Keep functions small and focused on a single task
2. **Validate Inputs**: Always validate user inputs before processing
3. **Provide Helpful Messages**: Include clear error and success messages
4. **Document Your Code**: Add comments to explain complex logic
5. **Test Thoroughly**: Write tests for all functionality, including edge cases
6. **Use Exit Codes**: Return appropriate exit codes to indicate success or failure
7. **Handle Errors Gracefully**: Catch and handle errors to prevent script crashes

## License

This template is provided under the terms of the LICENSE file included in the repository. 