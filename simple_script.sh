#!/bin/bash
# ==============================================================================
# Simple Script Template
# ==============================================================================
# Description:
#   A lightweight template for creating shell scripts with basic command-line
#   argument handling and file operations in the /tmp directory.
#
# Usage:
#   ./simple_script.sh [OPTIONS] ACTION
#
# Options:
#   -h, --help              Display this help message and exit
#   -f, --filename NAME     Specify the filename to create/list/delete in /tmp
#   --version               Display version information and exit
#
# Actions:
#   create                  Create a new file in /tmp with the specified name
#   list                    List files in /tmp matching pattern
#   delete                  Delete the specified file from /tmp
#
# Examples:
#   ./simple_script.sh --filename test.txt create
#   ./simple_script.sh --filename "test*" list
#   ./simple_script.sh --filename test.txt delete
#
# Exit Codes:
#   0  Success
#   1  General error
#   2  Invalid option or argument
#   3  File not found
# ==============================================================================

# Script version
VERSION="1.0.0"

# Default configuration
FILENAME="default_file.txt"
ACTION=""

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: ./simple_script.sh [OPTIONS] ACTION"
            echo ""
            echo "Options:"
            echo "  -h, --help              Display this help message and exit"
            echo "  -f, --filename NAME     Specify the filename to create in /tmp"
            echo "  --version               Display version information and exit"
            echo ""
            echo "Actions:"
            echo "  create                  Create a new file in /tmp with the specified name"
            echo "  list                    List files in /tmp matching pattern"
            echo "  delete                  Delete the specified file from /tmp"
            echo ""
            echo "Examples:"
            echo "  ./simple_script.sh --filename test.txt create"
            echo "  ./simple_script.sh --filename \"test*\" list"
            echo "  ./simple_script.sh --filename test.txt delete"
            exit 0
            ;;
        -f|--filename)
            FILENAME="$2"
            shift 2
            ;;
        --version)
            echo "Simple Script Version $VERSION"
            echo "Copyright (c) $(date +%Y)"
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option $1" >&2
            exit 2
            ;;
        *)
            if [[ -z "$ACTION" ]]; then
                ACTION="$1"
            else
                echo "ERROR: Only one action can be specified" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Check if an action was specified
if [[ -z "$ACTION" ]]; then
    echo "ERROR: No action specified. Use --help for usage information." >&2
    exit 2
fi

# Handle the specified action
case "$ACTION" in
    create)
        # Create a new file in /tmp with the specified name
        if touch "/tmp/$FILENAME"; then
            echo "Created file: /tmp/$FILENAME"
            exit 0
        else
            echo "Failed to create file /tmp/$FILENAME" >&2
            exit 1
        fi
        ;;
        
    list)
        # List files in /tmp matching the specified pattern
        if ls -la /tmp | grep "$FILENAME"; then
            exit 0
        else
            echo "No files found matching pattern $FILENAME"
            exit 0
        fi
        ;;
        
    delete)
        # Delete the specified file from /tmp
        # First check if the file exists
        if [[ ! -f "/tmp/$FILENAME" ]]; then
            echo "File not found: /tmp/$FILENAME"
            exit 3
        fi
        
        # Then attempt to delete it
        if rm -f "/tmp/$FILENAME"; then
            echo "Deleted file: /tmp/$FILENAME"
            exit 0
        else
            echo "Failed to delete file /tmp/$FILENAME" >&2
            exit 1
        fi
        ;;
        
    *)
        echo "ERROR: Unknown action: $ACTION. Use --help for usage information." >&2
        exit 2
        ;;
esac 