#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Get current date and username
current_date=$(date '+%Y-%m-%d %H:%M:%S')
current_user=$(whoami)

echo -e "${BLUE}${BOLD}Bonus Files Naming Convention Check${NC}"
echo -e "Current Date and Time: ${current_date}"
echo -e "Current User's Login: ${current_user}\n"

# Check if Makefile exists
if [ ! -f "Makefile" ]; then
    echo -e "${RED}Error: Makefile not found in current directory${NC}"
    exit 1
fi

# Check for bonus directories
src_bonus_dir="src_bonus"
inc_bonus_dir="include_bonus"
bonus_dirs=()

if [ -d "$src_bonus_dir" ]; then
    bonus_dirs+=("$src_bonus_dir")
fi

if [ -d "$inc_bonus_dir" ]; then
    bonus_dirs+=("$inc_bonus_dir")
fi

# Check for bonus rule in Makefile
if grep -q "^bonus:" Makefile; then
    echo -e "${GREEN}✓ 'bonus:' rule found in Makefile${NC}"
else
    echo -e "${RED}✗ No 'bonus:' rule found in Makefile${NC}"
fi

# Function to check files in directory
check_files_in_dir() {
    local dir=$1
    local total_files=0
    local correctly_named=0
    local incorrectly_named=0
    
    echo -e "\n${YELLOW}Checking files in ${BOLD}$dir${NC}"
    
    # Find all .c and .h files in the directory
    mapfile -t all_files < <(find "$dir" -type f \( -name "*.c" -o -name "*.h" \) | sort)
    total_files=${#all_files[@]}
    
    if [ $total_files -eq 0 ]; then
        echo -e "${YELLOW}  No .c or .h files found in $dir${NC}"
        return
    fi
    
    echo -e "${BLUE}  Found $total_files files to check${NC}"
    
    # Check each file for proper naming
    for file in "${all_files[@]}"; do
        filename=$(basename "$file")
        if [[ "$filename" == *"_bonus."* ]]; then
            echo -e "${GREEN}  ✓ $file correctly follows naming convention${NC}"
            ((correctly_named++))
        else
            echo -e "${RED}  ✗ $file does NOT follow _bonus naming convention${NC}"
            ((incorrectly_named++))
        fi
    done
    
    # Summary for this directory
    echo -e "\n${YELLOW}  Summary for $dir:${NC}"
    echo -e "  Total files: $total_files"
    echo -e "  Correctly named files: $correctly_named"
    echo -e "  ${RED}Incorrectly named files: $incorrectly_named${NC}"
}

# Check each bonus directory
if [ ${#bonus_dirs[@]} -eq 0 ]; then
    echo -e "${YELLOW}No bonus directories found (looked for $src_bonus_dir and $inc_bonus_dir)${NC}"
    
    # Try to find any _bonus files anywhere
    echo -e "\n${BLUE}Searching for any _bonus files in project...${NC}"
    bonus_files=$(find . -type f -name "*_bonus.c" -o -name "*_bonus.h" | sort)
    
    if [ -z "$bonus_files" ]; then
        echo -e "${RED}No files with '_bonus.c' or '_bonus.h' suffix found anywhere${NC}"
    else
        echo -e "${GREEN}Found bonus files with proper naming convention:${NC}"
        echo "$bonus_files" | sed 's/^/  /'
    fi
else
    for dir in "${bonus_dirs[@]}"; do
        check_files_in_dir "$dir"
    done
fi

# Final conclusion
echo -e "\n${BLUE}${BOLD}Conclusion:${NC}"
if [ ${#bonus_dirs[@]} -gt 0 ]; then
    echo -e "${YELLOW}According to the project requirements:${NC}"
    echo -e "\"Los bonus deben estar en archivos distintos _bonus.{c/h}. La parte obligatoria y los bonus se evalúan por separado.\""
    echo -e "${YELLOW}Make sure ALL your bonus files have the _bonus suffix in their filenames.${NC}"
else
    echo -e "${YELLOW}Either rename your bonus implementation files to include _bonus suffix${NC}"
    echo -e "${YELLOW}or organize them in separate directories like $src_bonus_dir.${NC}"
fi