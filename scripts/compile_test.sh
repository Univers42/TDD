#!/bin/bash
# Test compilation with various flags and settings

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Directory to scan (current directory by default)
TARGET_DIR=${1:-.}

# Find Makefile
if [ -f "$TARGET_DIR/Makefile" ]; then
    MAKEFILE_PATH="$TARGET_DIR/Makefile"
    echo "Found Makefile at $MAKEFILE_PATH"
    report_progress 10
else
    # Look for C files if no Makefile
    echo "No Makefile found. Looking for C files..."
    C_FILES=$(find "$TARGET_DIR" -type f -name "*.c" | sort)
    C_FILES_COUNT=$(echo "$C_FILES" | wc -l)
    
    if [ "$C_FILES_COUNT" -eq 0 ]; then
        echo "No C files found in $TARGET_DIR"
        report_progress 100
        exit 1
    fi
    
    echo "Found $C_FILES_COUNT C files to compile"
fi

echo "Testing compilation with different flags..."
report_progress 20

# Create temp directory for test builds
TEST_DIR=$(mktemp -d)
echo "Using temporary directory: $TEST_DIR"

# Array of test configurations
CONFIGS=(
    "Basic compilation:-Wall"
    "Strict warnings:-Wall -Wextra -Werror"
    "Full optimization:-O3 -Wall -Wextra"
    "Debug build:-g -Wall -Wextra"
    "ANSI C:-ansi -pedantic -Wall -Wextra"
    "C99 standard:-std=c99 -Wall -Wextra"
)

TOTAL_TESTS=${#CONFIGS[@]}
PASSED=0
CURRENT=0

# Run tests
for CONFIG in "${CONFIGS[@]}"; do
    # Split config into name and flags
    NAME=${CONFIG%%:*}
    FLAGS=${CONFIG#*:}
    CURRENT=$((CURRENT + 1))
    
    echo ""
    echo "[$CURRENT/$TOTAL_TESTS] Testing: $NAME"
    echo "Flags: $FLAGS"
    
    report_progress $((20 + (CURRENT * 70 / TOTAL_TESTS)))
    
    # Test compilation
    if [ -n "$MAKEFILE_PATH" ]; then
        # Use Makefile but with custom flags
        (cd "$TARGET_DIR" && make CFLAGS="$FLAGS" -B > "$TEST_DIR/build_output_$CURRENT.log" 2>&1)
        STATUS=$?
    else
        # Manual compilation
        gcc $FLAGS $C_FILES -o "$TEST_DIR/test_program_$CURRENT" > "$TEST_DIR/build_output_$CURRENT.log" 2>&1
        STATUS=$?
    fi
    
    # Check result
    if [ $STATUS -eq 0 ]; then
        echo "✅ PASS: Compilation successful"
        PASSED=$((PASSED + 1))
    else
        echo "❌ FAIL: Compilation failed"
        echo "Error output:"
        cat "$TEST_DIR/build_output_$CURRENT.log" | head -n 10
        if [ $(wc -l < "$TEST_DIR/build_output_$CURRENT.log") -gt 10 ]; then
            echo "... (see full log for more errors)"
        fi
    fi
done

# Print summary
echo ""
echo "========================== SUMMARY =========================="
echo "Total configurations tested: $TOTAL_TESTS"
echo "Passed: $PASSED"
echo "Failed: $((TOTAL_TESTS - PASSED))"
echo "============================================================"

# Clean up
rm -rf "$TEST_DIR"
report_progress 100

# Return success if all passed
if [ $PASSED -eq $TOTAL_TESTS ]; then
    exit 0
else
    exit 1
fi
