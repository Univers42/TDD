#!/bin/bash

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default Makefile path
MAKEFILE_PATH="./Makefile"

# Check if a custom Makefile path was provided
if [ "$1" ]; then
    MAKEFILE_PATH="$1"
fi

# Check if Makefile exists
if [ ! -f "$MAKEFILE_PATH" ]; then
    echo -e "${RED}Error:${RESET} Makefile not found at $MAKEFILE_PATH"
    exit 1
fi

echo -e "${BLUE}=== Checking Makefile Dependency Rules ===${RESET}"
echo -e "${YELLOW}Analyzing:${RESET} $MAKEFILE_PATH"
echo ""

# Function to check library compilation
check_library_compilation() {
    # Look for make -C or $(MAKE) -C patterns
    local lib_make_calls=$(grep -E '(\$\(MAKE\)|make).*-C' "$MAKEFILE_PATH" | grep -v '^#')
    
    if [ -z "$lib_make_calls" ]; then
        echo -e "${RED}✗ No calls to compile libraries using their Makefiles found${RESET}"
        echo -e "  Required: The Makefile should call another Makefile to compile a library first"
        return 1
    else
        echo -e "${GREEN}✓ Found calls to compile libraries using their Makefiles:${RESET}"
        echo "$lib_make_calls" | while read -r line; do
            echo -e "  ${YELLOW}→${RESET} $line"
        done
        return 0
    fi
}

# Function to check main target dependencies
check_main_target_dependencies() {
    # Find the main target (typically the first one or 'all')
    local main_target=$(grep -E '^all:' "$MAKEFILE_PATH" || grep -E '^[a-zA-Z0-9_-]+:' "$MAKEFILE_PATH" | head -1)
    
    if [ -z "$main_target" ]; then
        echo -e "${RED}✗ Could not identify the main target in the Makefile${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Main target found:${RESET} $main_target"
    
    # Check if all depends on a variable that might be a library
    if [[ "$main_target" =~ \$\([A-Za-z0-9_-]+\) ]]; then
        echo -e "${GREEN}✓ Main target depends on variables that could be libraries${RESET}"
        
        # Look for library variables in the Makefile
        local lib_vars=$(grep -E '=[^=]*\.a' "$MAKEFILE_PATH" | grep -v '^#')
        if [ -n "$lib_vars" ]; then
            echo -e "  ${GREEN}Found library variable definitions:${RESET}"
            echo "$lib_vars" | while read -r line; do
                echo -e "  ${YELLOW}→${RESET} $line"
            done
        fi
        
        return 0
    fi
    
    # Extract dependency information
    local target_name=$(echo "$main_target" | cut -d':' -f1)
    local target_deps=$(echo "$main_target" | cut -d':' -f2)
    
    # Look for library dependencies in the main target
    if [[ "$target_deps" == *"lib"* ]]; then
        echo -e "${GREEN}✓ Main target depends on a library (found 'lib' in dependencies)${RESET}"
        return 0
    elif [[ "$target_deps" == *".a"* ]]; then
        echo -e "${GREEN}✓ Main target depends on a static library (found '.a' in dependencies)${RESET}"
        return 0
    else
        # Check recipe for the target to see if it uses the library
        local target_recipe=$(sed -n "/^$target_name:/,/^[a-zA-Z0-9_-]\+:/p" "$MAKEFILE_PATH")
        if [[ "$target_recipe" == *"lib"* ]]; then
            echo -e "${GREEN}✓ Main target appears to use a library in its recipe${RESET}"
            return 0
        else
            # Check for order-only prerequisites
            if grep -q "\$(NAME):.*|.*\$(LIB[A-Za-z0-9_-]*)" "$MAKEFILE_PATH"; then
                echo -e "${GREEN}✓ Found name target with order-only prerequisite on library${RESET}"
                return 0
            else
                echo -e "${RED}✗ Main target does not appear to depend on a library${RESET}"
                echo -e "  Required: The main target should depend on or use the library"
                return 1
            fi
        fi
    fi
}

# Function to check build order
check_build_order() {
    # Check for either:
    # 1. The main targets depends on a library var
    # 2. The library is compiled through a dedicated rule and used as prerequisite
    # 3. The library is built through an order-only prerequisite

    # Check for pattern like $(NAME): $(OBJS) | $(LIBFT)
    if grep -q "\$(NAME):.*|.*\$(LIB[A-Za-z0-9_-]*)" "$MAKEFILE_PATH"; then
        echo -e "${GREEN}✓ Found proper order-only prerequisite ensuring library is built first${RESET}"
        echo -e "  Pattern: \$(NAME): ... | \$(LIBFT) or similar"
        return 0
    fi
    
    # Check for a dedicated rule for the library
    if grep -q "^\$(LIB[A-Za-z0-9_-]*):" "$MAKEFILE_PATH"; then
        echo -e "${GREEN}✓ Found dedicated rule for library compilation${RESET}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠ Could not definitively verify build order${RESET}"
    echo -e "  Checking for library usage patterns..."
    
    # Look for copying the library to the output
    if grep -q "cp \$(LIB[A-Za-z0-9_-]*) \$(NAME)" "$MAKEFILE_PATH"; then
        echo -e "${GREEN}✓ Found library copy to output file - suggests correct dependency${RESET}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠ Manual inspection recommended${RESET}"
    return 1
}

# Main checks
echo -e "${BLUE}Checking if library is compiled first using its own Makefile...${RESET}"
check_library_compilation
LIB_CHECK=$?

echo ""
echo -e "${BLUE}Checking main target dependencies...${RESET}"
check_main_target_dependencies
DEP_CHECK=$?

echo ""
echo -e "${BLUE}Checking build order...${RESET}"
check_build_order
ORDER_CHECK=$?

echo ""
echo -e "${BLUE}=== Summary ===${RESET}"
if [ $LIB_CHECK -eq 0 ] && ( [ $DEP_CHECK -eq 0 ] || [ $ORDER_CHECK -eq 0 ] ); then
    echo -e "${GREEN}✓ The Makefile appears to follow the required rule:${RESET}"
    echo -e "  It compiles a library first using the library's Makefile, then compiles the main project."
else
    echo -e "${RED}✗ The Makefile may not fully comply with the required rule:${RESET}"
    echo -e "  It should compile a library first using the library's Makefile, then compile the main project."
    echo -e ""
    echo -e "${YELLOW}Recommendations:${RESET}"
    
    if [ $LIB_CHECK -ne 0 ]; then
        echo -e "  - Add a call to compile the library using its own Makefile (e.g., \$(MAKE) -C libdir)"
    fi
    
    if [ $DEP_CHECK -ne 0 ] && [ $ORDER_CHECK -ne 0 ]; then
        echo -e "  - Make the main target depend on the library"
        echo -e "  - Ensure proper dependency ordering to build the library before the main project"
    fi
fi