#!/bin/bash
# Check that all files have consistent author information (anti-cheating)

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Directory to scan (current directory by default)
TARGET_DIR=${1:-.}

# Define colors for output
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m" 
COLOR_YELLOW="\033[0;33m"
COLOR_RESET="\033[0m"

echo "Checking for author consistency across C/C++ source files..."
report_progress 10

# Find only C/C++ code files
FILES=$(find "$TARGET_DIR" -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) | sort)
FILE_COUNT=$(echo "$FILES" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No source files found in $TARGET_DIR"
    report_progress 100
    exit 0
fi

echo "Found $FILE_COUNT files to analyze"
report_progress 20

# Read files into an array
readarray -t FILE_ARRAY <<< "$FILES"

# Stats and author tracking
PROCESSED=0
MISSING_AUTHOR=0
AUTHORS_FOUND=()
AUTHOR_FILES=()
AUTHOR_EMAILS=()

# Extract authors from all files first
for file in "${FILE_ARRAY[@]}"; do
    PROCESSED=$((PROCESSED + 1))
    PROGRESS=$((20 + (PROCESSED * 40 / FILE_COUNT)))
    report_progress $PROGRESS
    
    FILENAME=$(basename "$file")
    
    # Extract the first 20 lines where header is likely to be found
    HEADER_CONTENT=$(head -n 20 "$file")
    
    # C/C++ files use /* comments */
    AUTHOR_LINE=$(echo "$HEADER_CONTENT" | grep -E "/\*.*By:.*@")
    
    if [ -z "$AUTHOR_LINE" ]; then
        echo "⚠️  No author information found in $FILENAME"
        MISSING_AUTHOR=$((MISSING_AUTHOR + 1))
        continue
    fi
    
    # Extract author name and email
    AUTHOR_NAME=$(echo "$AUTHOR_LINE" | sed -n 's/.*By:[[:space:]]*\([^<]*\)<.*/\1/p' | xargs)
    AUTHOR_EMAIL=$(echo "$AUTHOR_LINE" | sed -n 's/.*<\([^>]*\)>.*/\1/p' | xargs)
    
    # Add to arrays if not already present
    FOUND=0
    for ((i=0; i<${#AUTHORS_FOUND[@]}; i++)); do
        if [ "${AUTHORS_FOUND[$i]}" == "$AUTHOR_NAME" ]; then
            # Author already found - increment file count
            AUTHOR_FILES[$i]=$((AUTHOR_FILES[$i] + 1))
            FOUND=1
            break
        fi
    done
    
    if [ "$FOUND" -eq 0 ]; then
        # New author found
        AUTHORS_FOUND+=("$AUTHOR_NAME")
        AUTHOR_EMAILS+=("$AUTHOR_EMAIL")
        AUTHOR_FILES+=(1)
    fi
done

# Process results
PROCESSED=0
DIFFERENT_AUTHORS="${#AUTHORS_FOUND[@]}"

# Display authors found
echo -e "\nAuthors found in codebase:"
for ((i=0; i<${#AUTHORS_FOUND[@]}; i++)); do
    echo "  - ${AUTHORS_FOUND[$i]} <${AUTHOR_EMAILS[$i]}> (in ${AUTHOR_FILES[$i]} files)"
    PROCESSED=$((PROCESSED + 1))
    PROGRESS=$((60 + (PROCESSED * 30 / DIFFERENT_AUTHORS)))
    report_progress $PROGRESS
done

# Analyze results
if [ "$DIFFERENT_AUTHORS" -gt 1 ]; then
    echo -e "\n${COLOR_RED}❌ INCONSISTENT AUTHORS DETECTED!${COLOR_RESET}"
    echo "Found $DIFFERENT_AUTHORS different authors in the codebase:"
    for ((i=0; i<${#AUTHORS_FOUND[@]}; i++)); do
        echo "  - ${AUTHORS_FOUND[$i]} <${AUTHOR_EMAILS[$i]}> (in ${AUTHOR_FILES[$i]} files)"
    done
    
    # List the first few files from each author as examples
    echo -e "\nSample files by author:"
    for ((i=0; i<${#AUTHORS_FOUND[@]}; i++)); do
        echo "Files by ${AUTHORS_FOUND[$i]}:"
        # Get first 3 files for this author
        count=0
        for file in "${FILE_ARRAY[@]}"; do
            HEADER_CONTENT=$(head -n 20 "$file")
            AUTHOR_LINE=$(echo "$HEADER_CONTENT" | grep -E "/\*.*By:.*${AUTHORS_FOUND[$i]}")
            
            if [ -n "$AUTHOR_LINE" ]; then
                echo "  - $file"
                count=$((count + 1))
                if [ "$count" -ge 3]; then
                    break
                fi
            fi
        done
    done
    
    echo -e "\nThis may indicate code was copied from multiple sources."
elif [ "$DIFFERENT_AUTHORS" -eq 1 ]; then
    echo -e "\n${COLOR_GREEN}✅ CONSISTENT AUTHOR${COLOR_RESET}"
    echo "All files authored by: ${AUTHORS_FOUND[0]} <${AUTHOR_EMAILS[0]}>"
    
    if [ "$MISSING_AUTHOR" -gt 0 ]; then
        echo -e "\n${COLOR_YELLOW}⚠️  Warning:${COLOR_RESET} $MISSING_AUTHOR files are missing author information"
    fi
else
    echo -e "\n${COLOR_YELLOW}⚠️  WARNING${COLOR_RESET}"
    echo "No author information found in any files!"
fi

report_progress 100

echo -e "\n====================== AUTHOR CHECK SUMMARY ======================"
echo "Files checked: $FILE_COUNT"
echo "Missing author info: $MISSING_AUTHOR"
echo "Different authors found: $DIFFERENT_AUTHORS"
echo "=================================================================="

# Return code:
# 0 = success (1 author across all files)
# 1 = failure (multiple authors found)
# -1 = warning (missing author info but no inconsistencies)
if [ "$DIFFERENT_AUTHORS" -gt 1 ]; then
    exit 1
elif [ "$MISSING_AUTHOR" -gt 0 ]; then
    exit -1
else
    exit 0
fi
