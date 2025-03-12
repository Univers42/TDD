#!/bin/bash
# Check files for proper 42 school header format

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Directory to scan (current directory by default)
TARGET_DIR=${1:-.}

echo "Searching for C/C++ source and header files in $TARGET_DIR..."
report_progress 10

# Find only C/C++ source and header files
FILES=$(find "$TARGET_DIR" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) | sort)
FILE_COUNT=$(echo "$FILES" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No C/C++ files found in $TARGET_DIR"
    report_progress 100
    exit 0
fi

echo "Found $FILE_COUNT files to check"
report_progress 20

# Define 42 header patterns with proper spacing
HEADER_START_REGEX="\/\* \*{10,} \*\/"
TITLE_REGEX="\/\*[[:space:]]*[^:]+:[[:space:]]*:[[:space:]]*:[[:space:]]*:[[:space:]]*:[[:space:]]*:[[:space:]]*:[[:space:]]*\*\/"
BY_LINE_REGEX="\/\*[[:space:]]*By:[[:space:]]+.*@.*\.[[:alpha:]]+[[:space:]]*\*\/"
CREATED_REGEX="\/\*[[:space:]]*Created:[[:space:]]+"
UPDATED_REGEX="\/\*[[:space:]]*Updated:[[:space:]]+"

# Stats counters
MISSING_HEADERS=0
INVALID_HEADERS=0
PROCESSED=0

# Read files into an array
readarray -t FILE_ARRAY <<< "$FILES"

for file in "${FILE_ARRAY[@]}"; do
    PROCESSED=$((PROCESSED + 1))
    PROGRESS=$((20 + (PROCESSED * 75 / FILE_COUNT)))
    report_progress $PROGRESS
    
    FILENAME=$(basename "$file")
    
    echo -e "\nChecking $file:"
    
    # Extract header (first 20 lines should be enough)
    HEADER_CONTENT=$(head -n 20 "$file")
    
    # Check if header exists
    if echo "$HEADER_CONTENT" | grep -q "\/\* \*"; then
        echo "✅ Found 42 header start line"
        
        # Count issues
        ISSUES=0
        
        # Instead of looking for filename in the title line with colons,
        # look for the filename line (typically has :+: pattern)
        FILENAME_LINE=$(echo "$HEADER_CONTENT" | grep -n ":[+]:" | head -n 1 | cut -d: -f2-)
        
        if [ -z "$FILENAME_LINE" ]; then
            echo "⚠️  Filename line with :+: pattern not found"
            ISSUES=$((ISSUES + 1))
        else
            # Extract the filename - it's the first text chunk in this line
            HEADER_FILENAME=$(echo "$FILENAME_LINE" | sed -n 's/\/\*[[:space:]]*\([^[:space:]]*\)[[:space:]]*.*/\1/p' | tr -d '[:space:]')
            
            echo "Extracted filename: '$HEADER_FILENAME'"
            
            if [ -z "$HEADER_FILENAME" ]; then
                echo "❌ Could not extract filename from header"
                ISSUES=$((ISSUES + 1))
            elif [ "$HEADER_FILENAME" != "$FILENAME" ]; then
                echo "❌ Filename mismatch: Header shows '$HEADER_FILENAME', actual file is '$FILENAME'"
                ISSUES=$((ISSUES + 1))
            else
                echo "✅ File name in header matches actual file name"
            fi
        fi
        
        # Check for title line (with ::: pattern)
        TITLE_LINE=$(echo "$HEADER_CONTENT" | grep -n ":::" | head -n 1 | cut -d: -f2-)
        
        if [ -z "$TITLE_LINE" ]; then
            echo "⚠️  Title line with ::: pattern not found"
            ISSUES=$((ISSUES + 1))
        else 
            # Check alignment of colons
            # The correct pattern should look like:
            #   :::      ::::::::
            if ! echo "$TITLE_LINE" | grep -q ":::[[:space:]]\{6\}::::::::"; then
                echo "❌ Incorrect formatting alignment in header"
                echo "   Should be: :::      ::::::::"
                ISSUES=$((ISSUES + 1))
            else
                echo "✅ Header formatting alignment looks correct"
            fi
        fi
        
        # Check for author line
        if echo "$HEADER_CONTENT" | grep -q "By:.*@.*\."; then
            echo "✅ Author line format OK"
        else
            echo "⚠️  Author line not found or incorrect format"
            ISSUES=$((ISSUES + 1))
        fi
        
        # Check for creation timestamp
        if echo "$HEADER_CONTENT" | grep -q "Created:"; then
            echo "✅ Creation timestamp OK"
        else
            echo "⚠️  Missing 'Created:' timestamp"
            ISSUES=$((ISSUES + 1))
        fi
        
        # Check for update timestamp
        if echo "$HEADER_CONTENT" | grep -q "Updated:"; then
            echo "✅ Update timestamp OK"
        else
            echo "⚠️  Missing 'Updated:' timestamp"
            ISSUES=$((ISSUES + 1))
        fi
        
        if [ "$ISSUES" -gt 0 ]; then
            echo "⚠️  Found $ISSUES issues in header"
            INVALID_HEADERS=$((INVALID_HEADERS + 1))
        else
            echo "✅ Header format is valid"
        fi
    else
        echo "❌ Missing 42 header - no line matching '/* *'"
        MISSING_HEADERS=$((MISSING_HEADERS + 1))
    fi
done

report_progress 100

echo -e "\n====================== HEADER FORMAT CHECK SUMMARY ======================"
echo "Files checked: $FILE_COUNT"
echo "Missing headers: $MISSING_HEADERS"
echo "Invalid headers: $INVALID_HEADERS"
echo "Valid headers: $((FILE_COUNT - MISSING_HEADERS - INVALID_HEADERS))"
echo "========================================================================"

# Return error code based on issues
if [ "$MISSING_HEADERS" -gt 0 ]; then
    exit 1
elif [ "$INVALID_HEADERS" -gt 0 ]; then
    exit -1  # Negative for warnings
else
    exit 0
fi
