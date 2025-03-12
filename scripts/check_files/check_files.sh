#!/bin/bash

# Check if file list is provided
if [[ -z "$1" ]]; then
    echo "❌ Usage: $0 <file_list.txt> [target_directory]"
    exit 1
fi

# File containing required file names
REQUIRED_LIST="$1"

# Check if the file exists
if [[ ! -f "$REQUIRED_LIST" ]]; then
    echo "❌ Error: File list '$REQUIRED_LIST' not found!"
    exit 1
fi

# Directory to check (default is current directory)
TARGET_DIR="${2:-.}"

# Read expected files into an array
mapfile -t expected_files < "$REQUIRED_LIST"

# Create an associative array to track expected files
declare -A expected_map
for file in "${expected_files[@]}"; do
    expected_map["$file"]=1
done

# Track found and missing files
found_files=()
missing_files=()

# Check for missing files
for file in "${expected_files[@]}"; do
    if [[ ! -e "$TARGET_DIR/$file" ]]; then
        missing_files+=("$file")
    else
        found_files+=("$file")
    fi
done

# Check for extra files in the directory
extra_files=()
while IFS= read -r file; do
    if [[ ! -v expected_map["$file"] ]]; then
        extra_files+=("$file")
    fi
done < <(ls "$TARGET_DIR")

# Report results
echo "✅ Using File List: $REQUIRED_LIST"
echo "📂 Checking Directory: $TARGET_DIR"
echo "--------------------------------"

echo "✅ Found Files: ${#found_files[@]}"
echo "❌ Missing Files: ${#missing_files[@]}"
for file in "${missing_files[@]}"; do
    echo "   - $file"
done

if [[ ${#extra_files[@]} -gt 0 ]]; then
    echo "⚠️ Extra Files Not in List:"
    for file in "${extra_files[@]}"; do
        echo "   - $file"
    done
fi

# Exit status: 0 if all files are present, 1 if some are missing
if [[ ${#missing_files[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
