#!/bin/bash
# Check project files with norminette

# Directory to scan (current directory by default)
TARGET_DIR=${1:-.}

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

echo "Searching for .c and .h files in $TARGET_DIR..."
report_progress 10

# Find all .c and .h files
FILES=$(find "$TARGET_DIR" -type f \( -name "*.c" -o -name "*.h" \) | sort)
FILE_COUNT=$(echo "$FILES" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No .c or .h files found in $TARGET_DIR"
    report_progress 100
    exit 1
fi

echo "Found $FILE_COUNT files to check"
report_progress 20

# Check each file with norminette
# Using an array to track errors to avoid subshell issues
ERROR_FILES=()
CURRENT=0

# Read files into an array to avoid pipeline subshell issues
readarray -t FILE_ARRAY <<< "$FILES"

# Process each file
for file in "${FILE_ARRAY[@]}"; do
    CURRENT=$((CURRENT + 1))
    PROGRESS=$((20 + (CURRENT * 75 / FILE_COUNT)))
    report_progress $PROGRESS
    
    echo -n "Checking $file: "
    NORM_OUTPUT=$(norminette "$file" 2>&1)
    
    if echo "$NORM_OUTPUT" | grep -q "OK!"; then
        echo "✅ OK"
    else
        echo "❌ Norminette errors:"
        echo "$NORM_OUTPUT" | grep -v "OK!" | sed 's/^/    /'
        ERROR_FILES+=("$file")
    fi
done

report_progress 100

ERROR_COUNT=${#ERROR_FILES[@]}
echo "Norminette check complete. $ERROR_COUNT files with errors found."

# Return error code explicitly based on error count
if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi
