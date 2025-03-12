#!/bin/bash
# Check that all files are authenticated by a valid 42 student

# Define colors for better output
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m" 
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_RESET="\033[0m"

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Directory to scan (current directory by default)
TARGET_DIR=${1:-.}

echo "Checking for 42 authentication across all source files..."
report_progress 10

# Find all code files
FILES=$(find "$TARGET_DIR" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) | sort)
FILE_COUNT=$(echo "$FILES" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No source files found in $TARGET_DIR"
    report_progress 100
    exit 0
fi

echo "Found $FILE_COUNT files to verify"
report_progress 20

# Regular expression for 42 email format
EMAIL_REGEX="[a-z0-9_-]+@student\.42\.[a-z]+"

# Stats tracking
PROCESSED=0
AUTHENTICATED=0
INVALID=0
MISSING=0

# Read files into an array
readarray -t FILE_ARRAY <<< "$FILES"

# Check each file
for file in "${FILE_ARRAY[@]}"; do
    PROCESSED=$((PROCESSED + 1))
    PROGRESS=$((20 + (PROCESSED * 75 / FILE_COUNT)))
    report_progress $PROGRESS
    
    FILENAME=$(basename "$file")
    echo -e "\nChecking $FILENAME:"
    
    # Extract the header content (first 20 lines)
    HEADER_CONTENT=$(head -n 20 "$file")
    
    # Look for By: line with 42 email format
    AUTHOR_LINE=$(echo "$HEADER_CONTENT" | grep -E "By:")
    
    if [ -z "$AUTHOR_LINE" ]; then
        echo -e "${COLOR_YELLOW}⚠️  No author information found${COLOR_RESET}"
        MISSING=$((MISSING + 1))
        continue
    fi
    
    # Extract author's email
    EMAIL=$(echo "$AUTHOR_LINE" | grep -o -E "<[^>]+" | tr -d '<')
    
    if [ -z "$EMAIL" ]; then
        echo -e "${COLOR_RED}❌ Could not extract email from author line${COLOR_RESET}"
        INVALID=$((INVALID + 1))
        continue
    fi
    
    echo "Found author email: $EMAIL"
    
    # Validate 42 email format
    if [[ $EMAIL =~ $EMAIL_REGEX ]]; then
        echo -e "${COLOR_GREEN}✅ Valid 42 student email verified${COLOR_RESET}"
        AUTHENTICATED=$((AUTHENTICATED + 1))
    else
        echo -e "${COLOR_RED}❌ Not a valid 42 student email${COLOR_RESET}"
        INVALID=$((INVALID + 1))
    fi
done

report_progress 100

echo -e "\n==================== 42 AUTHENTICATION SUMMARY ===================="
echo "Files checked: $FILE_COUNT"
echo -e "Authenticated files: ${COLOR_GREEN}$AUTHENTICATED${COLOR_RESET}"
echo -e "Invalid authentication: ${COLOR_RED}$INVALID${COLOR_RESET}"
echo -e "Missing authentication: ${COLOR_YELLOW}$MISSING${COLOR_RESET}"
echo "=================================================================="

# Calculate authentication rate
AUTH_RATE=$((AUTHENTICATED * 100 / FILE_COUNT))
echo "Authentication rate: $AUTH_RATE%"

# Return code based on authentication
if [ "$AUTHENTICATED" -eq "$FILE_COUNT" ]; then
    echo -e "${COLOR_GREEN}All files properly authenticated by 42 students.${COLOR_RESET}"
    exit 0
elif [ "$AUTH_RATE" -ge 80 ]; then
    echo -e "${COLOR_YELLOW}Most files authenticated, but some issues found.${COLOR_RESET}"
    exit -1
else
    echo -e "${COLOR_RED}Authentication issues detected. Please verify file headers.${COLOR_RESET}"
    exit 1
fi
