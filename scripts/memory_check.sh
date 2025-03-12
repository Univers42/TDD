#!/bin/bash
# Check for memory leaks in the program

# Progress reporting function - moved to the beginning
function report_progress {
    if [ -n "$PROGRESS_FD" ]; then
        echo "$1" >&$PROGRESS_FD
    fi
}

# Set up interactive mode flag
INTERACTIVE_MODE=0
INPUT_FILE=""

# Parse options
while getopts "i:I" opt; do
  case $opt in
    i) # Input file
      INPUT_FILE="$OPTARG"
      ;;
    I) # Interactive mode
      INTERACTIVE_MODE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# Shift to get the non-option arguments
shift $((OPTIND-1))

# Check if program name is provided
if [ $# -eq 0 ]; then
    # Check if there's a Makefile and try to build
    if [ -f "Makefile" ]; then
        echo "No program specified, but found a Makefile. Building..."
        report_progress 10
        make > /dev/null 2>&1
        
        # Find executable (assuming it's the one recently created)
        EXECUTABLE=$(find . -type f -executable -not -path "*/\.*" -printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d' ' -f2-)
        echo "Found executable: $EXECUTABLE"
    else
        echo "Error: No program specified and no Makefile found."
        echo "Usage: $0 [-i input_file] [-I] <program> [arguments]"
        echo "Options:"
        echo "  -i <file>  Provide an input file for the program"
        echo "  -I         Run in interactive mode (allows you to type input)"
        report_progress 100
        exit 1
    fi
else
    EXECUTABLE="$1"
    shift
    ARGS="$@"
fi

# Check if valgrind is installed
if ! command -v valgrind &> /dev/null; then
    echo "Error: valgrind is not installed. Please install it first."
    report_progress 100
    exit 2
fi

# Check if executable exists and is executable
if [ ! -f "$EXECUTABLE" ] || [ ! -x "$EXECUTABLE" ]; then
    echo "Error: $EXECUTABLE is not an executable file."
    report_progress 100
    exit 3
fi

echo "Running memory check on $EXECUTABLE..."
report_progress 30

# Display input method
if [ -n "$INPUT_FILE" ]; then
    echo "Using input file: $INPUT_FILE"
elif [ "$INTERACTIVE_MODE" -eq 1 ]; then
    echo "Running in INTERACTIVE mode - you can type input directly"
else
    echo "No input file provided. Program will run without input."
fi

echo "Valgrind analysis in progress..."
report_progress 50

# Run valgrind with the appropriate input method
if [ -n "$INPUT_FILE" ]; then
    # Use input file
    VALGRIND_OUTPUT=$(valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose "$EXECUTABLE" $ARGS < "$INPUT_FILE" 2>&1)
elif [ "$INTERACTIVE_MODE" -eq 1 ]; then
    # Interactive mode - run valgrind without capturing stdout/stderr
    echo "Starting interactive session. Type your input:"
    echo "-------------------------------------------"
    valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose "$EXECUTABLE" $ARGS
    VALGRIND_RESULT=$?
    echo "-------------------------------------------"
    echo "Interactive session ended."
    report_progress 90
    
    # Set simple pass/fail result
    if [ $VALGRIND_RESULT -eq 0 ]; then
        echo "Program exited normally."
    else
        echo "Program exited with code $VALGRIND_RESULT"
    fi
    
    echo "For full details, check valgrind's output above."
    report_progress 100
    exit $VALGRIND_RESULT
else
    # No input
    VALGRIND_OUTPUT=$(valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose "$EXECUTABLE" $ARGS 2>&1)
fi

# Only execute this section for non-interactive mode
if [ "$INTERACTIVE_MODE" -eq 0 ]; then
    # Parse valgrind output for summary
    LEAKS=$(echo "$VALGRIND_OUTPUT" | grep -A1 "LEAK SUMMARY")
    HEAP_SUMMARY=$(echo "$VALGRIND_OUTPUT" | grep -A4 "HEAP SUMMARY")
    ERROR_SUMMARY=$(echo "$VALGRIND_OUTPUT" | grep "ERROR SUMMARY")

    # Print results
    echo ""
    echo "====================== MEMORY CHECK RESULTS ======================"

    if echo "$ERROR_SUMMARY" | grep -q "0 errors"; then
        echo "✅ No memory errors detected."
    else
        echo "❌ Memory errors detected:"
        echo "$ERROR_SUMMARY"
    fi

    echo ""
    echo "Leak summary:"
    echo "$LEAKS"

    echo ""
    echo "Heap summary:"
    echo "$HEAP_SUMMARY"

    echo ""
    echo "For full details, run: valgrind --leak-check=full $EXECUTABLE"
    echo "================================================================="
fi

report_progress 100

# Return exit code based on memory leaks
if [ "$INTERACTIVE_MODE" -eq 0 ] && echo "$ERROR_SUMMARY" | grep -q "0 errors"; then
    exit 0
else
    exit 1
fi
