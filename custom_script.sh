#!/bin/bash
# ==============================================================================
# Custom Script Template
# ==============================================================================
# Description:
#   A template for creating custom scripts with standardized command-line
#   argument handling, logging, and error handling.
#
# Usage:
#   ./custom_script.sh [OPTIONS] ACTION
#
# Options:
#   -h, --help              Display this help message and exit
#   -v, --verbose           Enable verbose output
#   -o, --output FILE       Write output to FILE
#   -d, --dry-run           Run script without making any actual changes
#   -f, --filename NAME     Specify the filename to create in /tmp
#   --version               Display version information and exit
#
# Actions:
#   create                  Create a new file in /tmp with the specified name
#   list                    List files in /tmp matching pattern
#   delete                  Delete the specified file from /tmp
#
# Exit Codes:
#   0  Success
#   1  General error
#   2  Invalid option or argument
#   3  File not found
#   4  Permission denied
#   5  Network error
# ==============================================================================

# Script version
VERSION="1.0.0"

# Default configuration
VERBOSE=false
DRY_RUN=false
OUTPUT_FILE=""
FILENAME="default_file.txt"
LOG_FILE="/tmp/custom_script_$$.log"
ACTION=""

# =============================================================================
# Helper Functions
# =============================================================================

# Display usage information
function show_help() {
    grep "^# " "$0" | cut -c 3- | sed -n '/^=====/,/^=====/p' | sed '/^=====/d'
    exit 0
}

# Display version information
function show_version() {
    echo "Custom Script Template Version $VERSION"
    echo "Copyright (c) $(date +%Y)"
    exit 0
}

# Log a message to stderr and optionally to a log file
# Usage: log [--error|--warning|--info|--debug] "message"
function log() {
    local level="INFO"
    
    # Process optional level argument
    if [[ "$1" == "--error" ]]; then
        level="ERROR"
        shift
    elif [[ "$1" == "--warning" ]]; then
        level="WARNING"
        shift
    elif [[ "$1" == "--info" ]]; then
        level="INFO"
        shift
    elif [[ "$1" == "--debug" ]]; then
        level="DEBUG"
        shift
    fi
    
    # Format the log message
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local log_msg="[$timestamp] [$level] $1"
    
    # Write to log file
    echo "$log_msg" >> "$LOG_FILE"
    
    # Output to console if verbose or if error/warning
    if [[ "$VERBOSE" == true ]] || [[ "$level" == "ERROR" ]] || [[ "$level" == "WARNING" ]]; then
        if [[ "$level" == "ERROR" ]]; then
            echo "$log_msg" >&2
        else
            echo "$log_msg"
        fi
    fi
}

# Display error message and exit
# Usage: die "error message" [exit_code]
function die() {
    log --error "$1"
    exit "${2:-1}"
}

# Check if a command exists
# Usage: command_exists "command_name"
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root" 4
    fi
}

# Execute a command, respecting dry-run mode
# Usage: safe_exec "command to run"
function safe_exec() {
    local cmd="$1"
    log --debug "Executing: $cmd"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would execute: $cmd"
        return 0
    else
        eval "$cmd"
        return $?
    fi
}

# Write output to file if specified
# Usage: write_output "content"
function write_output() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$1" >> "$OUTPUT_FILE"
    fi
}

# Cleanup function to be called on exit
function cleanup() {
    log --debug "Cleaning up resources..."
    # Add cleanup actions here
    
    if [[ "$VERBOSE" == true ]]; then
        log --info "Log file is available at $LOG_FILE"
    else
        rm -f "$LOG_FILE"
    fi
}

# =============================================================================
# Command-line Argument Parsing
# =============================================================================

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -o|--output)
            if [[ -z "$2" || "$2" == -* ]]; then
                die "Option --output requires an argument" 2
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--filename)
            if [[ -z "$2" || "$2" == -* ]]; then
                die "Option --filename requires an argument" 2
            fi
            FILENAME="$2"
            shift 2
            ;;
        --version)
            show_version
            ;;
        -*)
            die "ERROR: Unknown option $1" 2
            ;;
        *)
            if [[ -z "$ACTION" ]]; then
                ACTION="$1"
            else
                die "ERROR: Only one action can be specified" 2
            fi
            shift
            ;;
    esac
done

# =============================================================================
# Input Validation and Setup
# =============================================================================

# Register the cleanup function to run on exit
trap cleanup EXIT

# Check if an action was specified
if [[ -z "$ACTION" ]]; then
    die "ERROR: No action specified. Use --help for usage information." 2
fi

# Validate the filename
if [[ -z "$FILENAME" ]]; then
    die "ERROR: Filename cannot be empty" 2
fi

# Initialize output file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    if [[ -f "$OUTPUT_FILE" ]]; then
        log --warning "Output file $OUTPUT_FILE already exists, it will be overwritten"
        cat /dev/null > "$OUTPUT_FILE"
    fi
    log --info "Output will be written to $OUTPUT_FILE"
    
    # Write header to output file
    echo "# Custom Script Output" > "$OUTPUT_FILE"
    echo "# Generated on: $(date)" >> "$OUTPUT_FILE"
    echo "# Action: $ACTION" >> "$OUTPUT_FILE"
    echo "# Filename: $FILENAME" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# Check for required commands
for cmd in touch ls rm grep; do
    if ! command_exists "$cmd"; then
        die "Required command '$cmd' not found" 1
    fi
done

# =============================================================================
# Action Implementation
# =============================================================================

# Handle the specified action
case "$ACTION" in
    create)
        log --info "Executing CREATE action for file $FILENAME"
        
        # Implementation for create action
        log --debug "Creating file in /tmp..."
        
        if safe_exec "touch /tmp/$FILENAME"; then
            log --info "File /tmp/$FILENAME created successfully"
            write_output "Status: Success"
            echo "Created file: /tmp/$FILENAME"
            exit 0
        else
            die "Failed to create file /tmp/$FILENAME" 1
        fi
        ;;
        
    list)
        log --info "Executing LIST action for pattern $FILENAME"
        
        # Implementation for list action
        log --debug "Listing files matching pattern..."
        
        if safe_exec "ls -la /tmp | grep $FILENAME"; then
            log --info "Files listed successfully"
            write_output "Status: Success"
            exit 0
        else
            log --warning "No files found matching pattern $FILENAME"
            write_output "Status: No files found"
            exit 0
        fi
        ;;
        
    delete)
        log --info "Executing DELETE action for file $FILENAME"
        
        # Implementation for delete action
        log --debug "Deleting file from /tmp..."
        
        if [[ ! -f "/tmp/$FILENAME" ]]; then
            log --warning "File /tmp/$FILENAME does not exist"
            write_output "Status: File not found"
            echo "File not found: /tmp/$FILENAME"
            exit 3
        fi
        
        if safe_exec "rm -f /tmp/$FILENAME"; then
            log --info "File /tmp/$FILENAME deleted successfully"
            write_output "Status: Success"
            echo "Deleted file: /tmp/$FILENAME"
            exit 0
        else
            die "Failed to delete file /tmp/$FILENAME" 1
        fi
        ;;
        
    *)
        die "ERROR: Unknown action: $ACTION. Use --help for usage information." 2
        ;;
esac

# This line should never be reached
die "ERROR: Script execution reached an unexpected point" 1 