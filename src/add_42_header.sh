#!/bin/bash
# Add 42 school header to files (if missing or invalid)

# Progress reporting function
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Configuration - Change these to match your info
AUTHOR_NAME="dyl-syzygy"
AUTHOR_EMAIL="dyl-syzygy@student.42.fr"

# Directory to process (current directory by default)
TARGET_DIR=${1:-.}

echo "Searching for code files in $TARGET_DIR..."
report_progress 10

# Find all source code files
FILES=$(find "$TARGET_DIR" -type f \( -name "*.c" -o -name "*.h" \) | sort)
FILE_COUNT=$(echo "$FILES" | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No C or header files found in $TARGET_DIR"
    report_progress 100
    exit 0
fi

echo "Found $FILE_COUNT files to process"
report_progress 20

# Read files into an array
readarray -t FILE_ARRAY <<< "$FILES"

# Files processed
PROCESSED=0
ADDED=0
SKIPPED=0

# Current date in the required format
CURRENT_DATE=$(date "+%Y/%m/%d %H:%M:%S")

for file in "${FILE_ARRAY[@]}"; do
    PROCESSED=$((PROCESSED + 1))
    PROGRESS=$((20 + (PROCESSED * 75 / FILE_COUNT)))
    report_progress $PROGRESS
    
    FILENAME=$(basename "$file")
    
    echo -n "Processing $file: "
    
    # Check if file already has a header
    if grep -q "\/\* \*\{74\} \*\/" "$file"; then
        echo "Header already exists, skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Create a temporary file
    TEMP_FILE=$(mktemp)
    
    # Add header to temp file
    cat > "$TEMP_FILE" << EOF
/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    $(printf "%-50s" "$FILENAME")  :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: $AUTHOR_NAME <$AUTHOR_EMAIL>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: $CURRENT_DATE by $AUTHOR_NAME        #+#    #+#              */
/*    Updated: $CURRENT_DATE by $AUTHOR_NAME       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

EOF
    
    # Append the original file content
    cat "$file" >> "$TEMP_FILE"
    
    # Replace original with new file
    mv "$TEMP_FILE" "$file"
    
    echo "Header added successfully"
    ADDED=$((ADDED + 1))
done

# Now process shell scripts and Makefile
SH_FILES=$(find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "Makefile" \) | sort)
SH_FILE_COUNT=$(echo "$SH_FILES" | wc -l)

if [ "$SH_FILE_COUNT" -gt 0 ]; then
    echo "Processing $SH_FILE_COUNT shell scripts and Makefiles..."
    
    # Read files into an array
    readarray -t SH_FILE_ARRAY <<< "$SH_FILES"
    
    for file in "${SH_FILE_ARRAY[@]}"; do
        PROCESSED=$((PROCESSED + 1))
        PROGRESS=$((20 + (PROCESSED * 75 / (FILE_COUNT + SH_FILE_COUNT))))
        report_progress $PROGRESS
        
        FILENAME=$(basename "$file")
        
        echo -n "Processing $file: "
        
        # Check if file already has a header
        if grep -q "# \*\{74\} #" "$file"; then
            echo "Header already exists, skipping"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        
        # For shell scripts, we need to be careful with the shebang line
        SHEBANG=""
        if [[ "$file" == *.sh ]]; then
            # Extract shebang if present
            SHEBANG=$(head -n 1 "$file" | grep "^#!")
        fi
        
        # Create a temporary file
        TEMP_FILE=$(mktemp)
        
        # Add shebang first if it existed
        if [ -n "$SHEBANG" ]; then
            echo "$SHEBANG" > "$TEMP_FILE"
        fi
        
        # Add header to temp file
        cat >> "$TEMP_FILE" << EOF
# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    $(printf "%-50s" "$FILENAME")  :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: $AUTHOR_NAME <$AUTHOR_EMAIL>      +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: $CURRENT_DATE by $AUTHOR_NAME        #+#    #+#              #
#    Updated: $CURRENT_DATE by $AUTHOR_NAME       ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

EOF

        # Append the original file content, skipping the shebang if we already added it
        if [ -n "$SHEBANG" ]; then
            tail -n +2 "$file" >> "$TEMP_FILE"
        else
            cat "$file" >> "$TEMP_FILE"
        fi
        
        # Replace original with new file
        mv "$TEMP_FILE" "$file"
        
        echo "Header added successfully"
        ADDED=$((ADDED + 1))
    done
fi

report_progress 100

echo -e "\n====================== HEADER ADDITION SUMMARY ======================"
echo "Files processed: $((FILE_COUNT + SH_FILE_COUNT))"
echo "Headers added: $ADDED"
echo "Files skipped (already had headers): $SKIPPED"
echo "======================================================================"

exit 0
