#!/bin/bash
# Test Coverage Utilities
# This script provides tools for measuring test coverage of shell scripts
#
# Usage:
#   source test_coverage.sh
#   run_with_coverage script.sh arg1 arg2
#   generate_report

# Set up coverage directory
COVERAGE_DIR="coverage"
mkdir -p "$COVERAGE_DIR"

#####################################################
# SECTION 1: SHELL SCRIPT COVERAGE
#####################################################

# Run a shell script with coverage tracking
run_with_coverage() {
    local script="$1"
    shift
    local script_name=$(basename "$script")
    local coverage_file="$COVERAGE_DIR/${script_name}.coverage"
    
    echo "Running $script_name with coverage tracking..."
    
    # Run script with debug output
    BASH_XTRACEFD=3 bash -x "$script" "$@" 3> >(
        # Process the debug output
        while read -r line; do
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line" >> "$coverage_file"
        done
    )
    
    local exit_code=$?
    echo "Coverage data saved to $coverage_file"
    return $exit_code
}

# Generate coverage report for shell scripts
generate_shell_report() {
    echo "Shell Script Coverage Report"
    echo "=========================="
    echo
    
    for coverage_file in "$COVERAGE_DIR"/*.coverage; do
        if [ -f "$coverage_file" ]; then
            script_name=$(basename "$coverage_file" .coverage)
            echo "Coverage for $script_name:"
            echo "-------------------------"
            
            # Find the script in common locations
            script_path=""
            for dir in "../utils" "../onboarding" "../automation" "../monitoring"; do
                if [ -f "$dir/$script_name" ]; then
                    script_path="$dir/$script_name"
                    break
                fi
            done
            
            if [ -z "$script_path" ]; then
                echo "Script file not found for $script_name"
                continue
            fi
            
            # Count executed lines
            executed_lines=$(grep -c '^+' "$coverage_file")
            
            # Count total executable lines (excluding comments and empty lines)
            total_lines=$(grep -v '^#' "$script_path" | grep -v '^[[:space:]]*$' | wc -l)
            
            # Calculate coverage percentage
            if [ "$total_lines" -gt 0 ]; then
                coverage=$((executed_lines * 100 / total_lines))
            else
                coverage=0
            fi
            
            echo "Lines executed: $executed_lines of $total_lines"
            echo "Coverage: $coverage%"
            echo
            
            # Show uncovered lines
            echo "Uncovered lines:"
            echo "---------------"
            line_num=1
            while IFS= read -r line; do
                if ! grep -q "^+ .*$line" "$coverage_file" && [[ "$line" =~ [^[:space:]] ]] && [[ ! "$line" =~ ^# ]]; then
                    echo "$line_num: $line"
                fi
                ((line_num++))
            done < "$script_path"
            echo
            echo
        fi
    done
}

#####################################################
# SECTION 2: PYTHON TEST COVERAGE
#####################################################

# Run Python tests with coverage
run_python_coverage() {
    echo "Running Python tests with coverage..."
    
    # Check if pytest-cov is installed
    if ! python -c "import pytest_cov" 2>/dev/null; then
        echo "Error: pytest-cov is not installed. Please install it with:"
        echo "pip install pytest-cov"
        return 1
    fi
    
    # Run pytest with coverage
    python -m pytest --cov=.. --cov-report=term --cov-report=html:$COVERAGE_DIR/html "$@"
    
    echo "Python coverage report generated in $COVERAGE_DIR/html"
}

#####################################################
# SECTION 3: COMBINED COVERAGE
#####################################################

# Generate combined coverage report
generate_report() {
    # Clean up previous coverage data
    rm -rf "$COVERAGE_DIR"
    mkdir -p "$COVERAGE_DIR"
    
    # Run shell script coverage
    generate_shell_report
    
    # If Python tests are available, run them too
    if [ -d "../tests" ]; then
        run_python_coverage
    fi
    
    echo "Coverage reports generated in $COVERAGE_DIR"
}

# Clean up coverage data
clean_coverage() {
    echo "Cleaning up coverage data..."
    rm -rf "$COVERAGE_DIR"
    mkdir -p "$COVERAGE_DIR"
    echo "Coverage data cleaned."
}

#####################################################
# SECTION 4: COMMAND HANDLING
#####################################################

# Show help
show_help() {
    echo "Test Coverage Utilities"
    echo "======================"
    echo
    echo "This script provides tools for measuring test coverage."
    echo
    echo "Available functions:"
    echo "  run_with_coverage <script> [args]  - Run a shell script with coverage tracking"
    echo "  generate_shell_report              - Generate coverage report for shell scripts"
    echo "  run_python_coverage [pytest_args]  - Run Python tests with coverage"
    echo "  generate_report                    - Generate combined coverage report"
    echo "  clean_coverage                     - Clean up coverage data"
    echo
    echo "Usage:"
    echo "  source test_coverage.sh"
    echo "  run_with_coverage ../onboarding/create_directory.sh server rstudio qhs user"
    echo "  generate_report"
}

# Export the functions
export -f run_with_coverage
export -f generate_shell_report
export -f run_python_coverage
export -f generate_report
export -f clean_coverage

# If script is executed directly, show help or run command if provided
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        show_help
    else
        # Execute the specified function
        "$@"
    fi
else
    echo "Test coverage utilities loaded. Use 'show_help' to see available functions."
fi 