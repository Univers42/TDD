#!/bin/bash
# check consistent use of allowed functions or prohibited functions


# =====================================================
# ===== PIPEX FUNCTION VALIDATOR - ULTIMATE EDITION ===
# =====================================================

# Define allowed glibc functions - only these external functions can be used
ALLOWED_FUNCTIONS=(
    "open" "close" "read" "write"
    "malloc" "free" "perror" "strerror"
    "access" "dup" "dup2" "execve"
    "exit" "fork" "pipe" "unlink"
    "wait" "waitpid" "printf"
)

# Define explicitly prohibited functions that should be caught
PROHIBITED_FUNCTIONS=(
    "strlen" "strcpy" "strcat" "strcmp" "strncmp"
    "strchr" "strrchr" "strstr" "strnstr"
    "memset" "memcpy" "memmove" "memchr" "memcmp"
    "isalpha" "isdigit" "isalnum" "isascii" "isprint"
    "toupper" "tolower" "bzero" "calloc" 
    "atoi" "itoa" "split" "join" "trim"
    "getline" "system" "signal"
)

# Enhanced colors and styles
RED='\033[1;31m'        # Bold Red
GREEN='\033[1;32m'      # Bold Green
YELLOW='\033[1;33m'     # Bold Yellow
BLUE='\033[1;34m'       # Bold Blue
CYAN='\033[1;36m'       # Bold Cyan
PURPLE='\033[1;35m'     # Bold Purple
WHITE='\033[1;37m'      # Bold White
RESET='\033[0m'         # Reset
BOLD='\033[1m'          # Bold
DIM='\033[2m'           # Dim

# Function to print stylish banners
print_banner() {
    local message="$1"
    local color="$2"
    local width=$(tput cols)
    local line=""
    
    # Create a line of appropriate width
    for ((i=0; i<width; i++)); do
        line="$line─"
    done
    
    # Print the banner
    echo -e "${color}${line}${RESET}"
    echo -e "${color}${BOLD}  $message  ${RESET}"
    echo -e "${color}${line}${RESET}"
}

# Function to display a magnificent progress bar
show_progress_bar() {
    local current=$1
    local total=$2
    local title="$3"
    local bar_length=40
    local filled_length=$((current * bar_length / total))
    
    # Characters for the progress bar (using Unicode characters for a fancier look)
    local fill_char="█"
    local empty_char="░"
    local start_char="╢"
    local end_char="╟"
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    
    # Create the bar
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar="$bar$fill_char"
    done
    
    for ((i=filled_length; i<bar_length; i++)); do
        bar="$bar$empty_char"
    done
    
    # Calculate how many files/sec
    local speed=""
    if [ -n "$4" ]; then
        local elapsed=$4
        if [ "$elapsed" -gt 0 ]; then
            local files_per_sec=$(echo "scale=1; $current / $elapsed" | bc)
            speed=" [${files_per_sec} files/sec]"
        fi
    fi
    
    # Print the progress bar with color
    echo -ne "\r${CYAN}$title ${BLUE}$start_char${GREEN}$bar${BLUE}$end_char ${YELLOW}$percent%${CYAN}$speed${RESET}"
    
    # Add a new line if we're at 100%
    if [ "$current" -eq "$total" ]; then
        echo -e "\n${GREEN}✓ Completed${RESET}"
    fi
}

# Start with a fancy header
clear
echo -e "\n"
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════${RESET}"
echo -e "${PURPLE}║                                                                ${RESET}"
echo -e "${PURPLE}║  ${BOLD}${WHITE}PIPEX FUNCTION VALIDATOR${RESET}${PURPLE}                                 ${RESET}"
echo -e "${PURPLE}║  ${DIM}Ensuring your code adheres to the allowed function rules${RESET}${PURPLE}        ${RESET}"
echo -e "${PURPLE}║                                                                ${RESET}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════${RESET}\n"

# Initialization
echo -e "${BOLD}${BLUE}⚡ Initializing validator...${RESET}"

# Find all .c and .h files in the directory
C_FILES=$(find . -name "*.c")
H_FILES=$(find . -name "*.h")
ALL_FILES="$C_FILES $H_FILES"

echo -e "${GREEN}✓ Found $(echo "$ALL_FILES" | wc -w) source files to analyze${RESET}"

# Step 1: Extract all unique function calls from all files
print_banner "PHASE 1: EXTRACTING FUNCTION CALLS" "$BLUE"
declare -A FUNCTION_CALLS
declare -A FUNCTION_CALL_LOCATIONS

# Pre-process: Check for explicitly prohibited functions using grep
echo -e "${CYAN}Performing quick scan for prohibited functions...${RESET}"
PROHIBITED_FOUND=0

for func in "${PROHIBITED_FUNCTIONS[@]}"; do
    # Use more precise regex to find function calls, excluding comments
    # Look for pattern: functionName( with word boundaries
    result=$(grep -rn "\<$func(" --include="*.c" --include="*.h" . | 
             grep -v "//.*\<$func(" |  # Exclude single-line comments
             grep -v "/\*.*\<$func(.*\*/" |  # Exclude block comments
             grep -v "^ \*" | # Exclude documentation comments
             grep -v "ft_$func(" # Exclude ft_ prefixed functions
    )
    
    if [ -n "$result" ]; then
        echo -e "${RED}❌ Found prohibited function: $func${RESET}"
        echo -e "${RED}$result${RESET}"
        PROHIBITED_FOUND=1
    fi
done

if [ $PROHIBITED_FOUND -eq 1 ]; then
    echo -e "${RED}Error: Prohibited functions detected. Please replace them with your own implementations.${RESET}"
    exit 1
fi

echo -e "${CYAN}Scanning files for function calls...${RESET}"
# Process files one by one
file_count=0
total_files=$(echo "$ALL_FILES" | wc -w)
start_time=$(date +%s)

for file in $ALL_FILES; do
    ((file_count++))
    
    # Show magnificent progress bar
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    show_progress_bar "$file_count" "$total_files" "Analyzing source files:" "$elapsed"
    
    # Process the file line by line to properly handle comments
    line_num=0
    in_comment_block=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comment lines and empty lines
        if [[ -z "${line// /}" ]]; then continue; fi
        
        # Handle comment blocks /* ... */
        if [[ "$line" =~ \/\* ]]; then
            in_comment_block=1
        fi
        if [[ "$line" =~ \*\/ ]]; then
            in_comment_block=0
            continue
        fi
        if [[ $in_comment_block -eq 1 ]]; then
            continue
        fi
        
        # Skip single-line comments
        if [[ "$line" =~ ^[[:space:]]*\/\/ ]]; then
            continue
        fi
        
        # Remove inline comments before processing the line
        cleaned_line=$(echo "$line" | sed 's/\/\/.*$//')
        
        # Extract function names from lines with function calls
        while [[ "$cleaned_line" =~ ([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; do
            func_name="${BASH_REMATCH[1]}"
            cleaned_line=${cleaned_line#*"${BASH_REMATCH[0]}"}
            
            case "$func_name" in
                "if"|"while"|"for"|"switch"|"return"|"sizeof"|"struct"|"enum"|"typedef"|"main"|"functions"|"name")
                    continue ;;
            esac
            
            # Skip common variable names that might be mistaken as functions
            if [[ "$func_name" == "functions" || "$func_name" == "name" ]]; then
                continue
            fi
            
            # Record this function call
            FUNCTION_CALLS["$func_name"]=1
            
            # Record where this function was called
            if [[ -z "${FUNCTION_CALL_LOCATIONS[$func_name]}" ]]; then
                FUNCTION_CALL_LOCATIONS["$func_name"]="$file:$line_num"
            else
                FUNCTION_CALL_LOCATIONS["$func_name"]="${FUNCTION_CALL_LOCATIONS[$func_name]},$file:$line_num"
            fi
        done
    done < "$file"
done
echo # New line after progress display

echo -e "${GREEN}✓ Found ${#FUNCTION_CALLS[@]} unique function calls${RESET}"

# Step 2: Find all function definitions across all files
print_banner "PHASE 2: IDENTIFYING FUNCTION DEFINITIONS" "$YELLOW"
declare -A FUNCTION_DEFINITIONS
declare -A FUNCTION_DEF_LOCATIONS

# Process header files
echo -e "${CYAN}Analyzing header files for prototypes...${RESET}"
for file in $H_FILES; do
    echo -ne "\r${CYAN}Scanning header: $(basename "$file")${RESET}"
    
    # Get whole file content to handle multi-line prototypes
    file_content=$(<"$file")
    
    # Remove comments to simplify parsing
    file_content=$(echo "$file_content" | sed 's/\/\*.*\*\///g; s/\/\/.*$//g')
    
    # Find all lines with semicolons that likely contain function prototypes
    while read -r line_num line; do
        # Skip empty lines
        if [[ -z "${line// /}" ]]; then continue; fi
        
        # Find function prototypes - look for word followed by open parenthesis before semicolon
        if [[ "$line" == *"("*")"*";"* ]]; then
            # Extract all words that are followed by parenthesis
            while [[ "$line" =~ ([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; do
                func_name="${BASH_REMATCH[1]}"
                
                # Skip if it's a common C keyword
                if [[ "$func_name" == "if" || "$func_name" == "while" || "$func_name" == "for" || "$func_name" == "switch" ]]; then
                    # Replace the match to avoid infinite loop
                    line=${line/${BASH_REMATCH[0]}/}
                    continue
                fi
                
                # Add to function definitions
                FUNCTION_DEFINITIONS["$func_name"]=1
                FUNCTION_DEF_LOCATIONS["$func_name"]="$file:$line_num (prototype)"
                
                # Replace the match to avoid infinite loop
                line=${line/${BASH_REMATCH[0]}/}
            done
        fi
    done < <(grep -n "" <<< "$file_content")
    
    # Also look for function prototypes that span multiple lines
    multiline_content=$(echo "$file_content" | tr '\n' ' ')
    
    # Find function prototypes with the pattern "type name(args);"
    while [[ "$multiline_content" =~ ([a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^;]*\);) ]]; do
        prototype="${BASH_REMATCH[1]}"
        
        # Extract the function name from the prototype
        if [[ "$prototype" =~ [[:space:]]([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
            func_name="${BASH_REMATCH[1]}"
            
            # Skip if it's a common C keyword
            if [[ "$func_name" == "if" || "$func_name" == "while" || "$func_name" == "for" || "$func_name" == "switch" ]]; then
                # Replace the match to avoid infinite loop
                multiline_content=${multiline_content/${BASH_REMATCH[0]}/}
                continue
            fi
            
            # Add to function definitions if not already there
            if [[ -z "${FUNCTION_DEFINITIONS[$func_name]}" ]]; then
                FUNCTION_DEFINITIONS["$func_name"]=1
                FUNCTION_DEF_LOCATIONS["$func_name"]="$file (multiline prototype)"
            fi
        fi
        
        # Replace the match to avoid infinite loop
        multiline_content=${multiline_content/${BASH_REMATCH[0]}/}
    done
done
echo # New line after header file processing

# Process C files
echo -e "${CYAN}Analyzing source files for definitions...${RESET}"
file_count=0
total_c_files=$(echo "$C_FILES" | wc -w)
start_time=$(date +%s)

for file in $C_FILES; do
    ((file_count++))
    
    # Show magnificent progress bar
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    show_progress_bar "$file_count" "$total_c_files" "Processing source definitions:" "$elapsed"
    
    # First check for static functions - these are only visible within their file
    while read -r line_num line; do
        # Skip comment lines and empty lines
        if [[ "$line" =~ ^[[:space:]]*(\*|\/\*|\*\/|\/\/) ]] || [[ -z "${line// /}" ]]; then
            continue
        fi
        
        # Match static function definitions - these are local to their files
        if [[ "$line" =~ ^[[:space:]]*static[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]]; then
            func_name="${BASH_REMATCH[1]}"
            FUNCTION_DEFINITIONS["$func_name"]=1
            FUNCTION_DEF_LOCATIONS["$func_name"]="$file:$line_num (static function)"
        fi
    done < <(grep -n "" "$file")
    
    # Extract function parameters from function definitions
    while read -r line_num line; do
        # Skip comment lines
        if [[ "$line" =~ ^[[:space:]]*(\*|\/\*|\*\/|\/\/) ]]; then continue; fi
        
        # Match standard function definition patterns
        if [[ "$line" =~ \([[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\* ]]; then
            # This is likely a function parameter that takes another function
            param_name="${BASH_REMATCH[1]}"
            FUNCTION_DEFINITIONS["$param_name"]=1
            FUNCTION_DEF_LOCATIONS["$param_name"]="$file:$line_num (function parameter)"
        elif [[ "$line" =~ \([[:space:]]*void[[:space:]]*\([[:space:]]*\*([a-zA-Z_][a-zA-Z0-9_]*)\) ]]; then
            # Function pointer parameter pattern like void (*f)(void *)
            param_name="${BASH_REMATCH[1]}"
            FUNCTION_DEFINITIONS["$param_name"]=1
            FUNCTION_DEF_LOCATIONS["$param_name"]="$file:$line_num (function pointer parameter)"
        fi
        
        # Check for helper function names in internal functions
        for helper in "safe_malloc" "ft_len" "count_segments" "allocate_and_copy_token" "allocate_and_copy_tokens" "f" "del"; do
            if grep -q "\<$helper\>" "$file"; then
                FUNCTION_DEFINITIONS["$helper"]=1
                FUNCTION_DEF_LOCATIONS["$helper"]="$file (static helper)"
            fi
        done
    done < <(grep -n "" "$file")
    
    # Need to handle multi-line functions and different formatting styles
    in_function=0
    current_function=""
    line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comment lines and empty lines
        if [[ "$line" =~ ^[[:space:]]*(\*|\/\*|\*\/|\/\/) ]] || [[ -z "${line// /}" ]]; then
            continue
        fi
        
        if [[ $in_function -eq 0 ]]; then
            # Look for function definition start (return_type function_name( with no semicolon)
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\( ]] && [[ ! "$line" == *";"* ]]; then
                func_name="${BASH_REMATCH[1]}"
                
                # If the line contains an opening brace, we found a single-line function start
                if [[ "$line" == *"{"* ]]; then
                    in_function=1
                    current_function="$func_name"
                    FUNCTION_DEFINITIONS["$func_name"]=1
                    FUNCTION_DEF_LOCATIONS["$func_name"]="$file:$line_num (definition)"
                else
                    # Look ahead for the opening brace
                    next_lines=$(head -n $((line_num + 10)) "$file" | tail -n 10)
                    if [[ "$next_lines" == *"{"* ]]; then
                        in_function=1
                        current_function="$func_name"
                        FUNCTION_DEFINITIONS["$func_name"]=1
                        FUNCTION_DEF_LOCATIONS["$func_name"]="$file:$line_num (multi-line definition)"
                    fi
                fi
            fi
        elif [[ "$line" == *"}"* ]]; then
            # End of function
            in_function=0
            current_function=""
        fi
    done < "$file"
done
echo # New line after C file processing

# Handle special cases and static helpers
echo -e "${CYAN}Processing edge cases...${RESET}"

# Handle special case for variable-like names
for func in "${!FUNCTION_CALLS[@]}"; do
    # Skip if already defined or in allowed list
    if [[ -n "${FUNCTION_DEFINITIONS[$func]}" ]] || printf '%s\n' "${ALLOWED_FUNCTIONS[@]}" | grep -q -x "$func"; then
        continue
    fi
    
    # Look for patterns that suggest this is a variable rather than a function
    for file in $ALL_FILES; do
        # Look for typical variable patterns
        if grep -q "\<$func\>[[:space:]]*=" "$file" || grep -q "\<$func\>[[:space:]]*\[" "$file"; then
            FUNCTION_DEFINITIONS["$func"]=1
            FUNCTION_DEF_LOCATIONS["$func"]="$file (likely variable, not function)"
            break
        fi
    done
done

# Additional treatment for edge cases
for func in "${!FUNCTION_CALLS[@]}"; do
    if [[ -z "${FUNCTION_DEFINITIONS[$func]}" ]]; then
        for file in $ALL_FILES; do
            # Look for contexts that suggest it's defined
            if grep -q "^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]\+$func[[:space:]]*(" "$file" || \
               grep -q "^$func[[:space:]]*(" "$file"; then
                FUNCTION_DEFINITIONS["$func"]=1
                FUNCTION_DEF_LOCATIONS["$func"]="$file (pattern match)"
                break
            fi
        done
    fi
done

echo -e "${GREEN}✓ Found ${#FUNCTION_DEFINITIONS[@]} function definitions${RESET}\n"

# Step 3: Verify each function call has a valid definition
print_banner "PHASE 3: VALIDATING FUNCTION CALLS" "$PURPLE" 

# Known false positives to ignore
declare -A FALSE_POSITIVES
FALSE_POSITIVES["functions"]=1
FALSE_POSITIVES["name"]=1

echo -e "${CYAN}Checking each function against allowed list and definitions...${RESET}"
VIOLATIONS_FOUND=0
VALID_CALLS=0
ALLOWED_CALLS=0

echo -e "\n${BOLD}Function validation results:${RESET}\n"
echo -e "┌─────────────────────────────────────────────────────────────┐"

# Create a temporary file for storing sorted results
TEMP_RESULTS=$(mktemp)

# Process function calls and write results to temp file
for func in "${!FUNCTION_CALLS[@]}"; do
    # Skip false positives
    if [[ -n "${FALSE_POSITIVES[$func]}" ]]; then
        echo "IGNORE   $func (known false positive)" >> "$TEMP_RESULTS"
        continue
    fi
    
    # Skip allowed glibc functions
    if printf '%s\n' "${ALLOWED_FUNCTIONS[@]}" | grep -q -x "$func"; then
        ((ALLOWED_CALLS++))
        echo "ALLOWED  $func (standard library)" >> "$TEMP_RESULTS"
        continue
    fi
    
    # Check for prohibited functions (belt-and-suspenders approach)
    if printf '%s\n' "${PROHIBITED_FUNCTIONS[@]}" | grep -q -x "$func"; then
        ((VIOLATIONS_FOUND++))
        echo "PROHIBITED $func (standard library function that must be reimplemented)" >> "$TEMP_RESULTS"
        
        # Print locations where this function is called
        IFS=',' read -ra locations <<< "${FUNCTION_CALL_LOCATIONS[$func]}"
        for loc in "${locations[@]}"; do
            file=$(echo "$loc" | cut -d: -f1)
            line=$(echo "$loc" | cut -d: -f2)
            echo "CALL     $func $file:$line" >> "$TEMP_RESULTS"
        done
        continue
    fi
    
    # Check if this function has a definition in our codebase
    if [[ -n "${FUNCTION_DEFINITIONS[$func]}" ]]; then
        ((VALID_CALLS++))
        echo "OK       $func (${FUNCTION_DEF_LOCATIONS[$func]})" >> "$TEMP_RESULTS"
        continue
    fi
    
    # If we get here, this is an unauthorized function
    ((VIOLATIONS_FOUND++))
    echo "ERROR    $func" >> "$TEMP_RESULTS"
    
    # Print locations where this function is called
    IFS=',' read -ra locations <<< "${FUNCTION_CALL_LOCATIONS[$func]}"
    for loc in "${locations[@]}"; do
        file=$(echo "$loc" | cut -d: -f1)
        line=$(echo "$loc" | cut -d: -f2)
        echo "CALL     $func $file:$line" >> "$TEMP_RESULTS"
    done
done

# Sort the results and properly format them with color when printing
sort "$TEMP_RESULTS" | while read -r line; do
    status=$(echo "$line" | cut -d' ' -f1)
    content=$(echo "$line" | cut -d' ' -f2-)
    
    case "$status" in
        "IGNORE")
            echo -e "│ ${BLUE}⚡ IGNORED${RESET}   $content" ;;
        "ALLOWED")
            echo -e "│ ${GREEN}✓ ALLOWED${RESET}   $content" ;;
        "OK")
            echo -e "│ ${GREEN}✓ OK${RESET}        $content" ;;
        "ERROR")
            echo -e "│ ${RED}❌ ERROR${RESET}     $content" ;;
        "PROHIBITED")
            echo -e "│ ${RED}⛔ PROHIBITED${RESET} $content" ;;
        "CALL")
            func=$(echo "$content" | cut -d' ' -f1)
            loc=$(echo "$content" | cut -d' ' -f2-)
            echo -e "│      ${RED}└─ Called in $loc${RESET}" ;;
    esac
done

# Clean up temp file
rm -f "$TEMP_RESULTS"

echo -e "└─────────────────────────────────────────────────────────────┘"

# Final report
echo -e "\n"
print_banner "VALIDATION REPORT" "$CYAN"

echo -e "  ${BOLD}Total function calls detected:${RESET}    ${#FUNCTION_CALLS[@]}"
echo -e "  ${BOLD}Standard library calls:${RESET}           $ALLOWED_CALLS"
echo -e "  ${BOLD}User-defined functions:${RESET}           $VALID_CALLS"
echo -e "  ${BOLD}Problematic functions:${RESET}            $VIOLATIONS_FOUND"
echo -e "  ${BOLD}Function definitions found:${RESET}       ${#FUNCTION_DEFINITIONS[@]}"

# Final status
if [ $VIOLATIONS_FOUND -eq 0 ]; then
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}║                                                                ${RESET}"
    echo -e "${GREEN}║  ${BOLD}✓ SUCCESS: All function calls are authorized!${RESET}${GREEN}               ${RESET}"
    echo -e "${GREEN}║  All functions are either from the allowed list or defined     ${RESET}"
    echo -e "${GREEN}║  in your project. Your code meets the requirements.            ${RESET}"
    echo -e "${GREEN}║                                                                ${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════${RESET}\n"
    exit 0
else
    echo -e "\n${RED}╔════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${RED}║                                                                ${RESET}"
    echo -e "${RED}║  ${BOLD}❌ ERROR: Unauthorized function calls detected!${RESET}${RED}               ${RESET}"
    echo -e "${RED}║  Please fix the $VIOLATIONS_FOUND problematic function(s) listed above.      ${RESET}"
    echo -e "${RED}║  All functions must be on the allowed list or defined in code.  ${RESET}"
    echo -e "${RED}║                                                                ${RESET}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════${RESET}\n"
    exit 1
fi