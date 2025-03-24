# 42 Project Assessment CLI Controller

An interactive command-line interface for automating project assessments at 42.

## Features

- 🎨 Animated and colorful user interface
- 🔍 Automatic script discovery and execution
- ⌨️ Intuitive keyboard navigation
- 📊 Live progress indicators
- 🚀 Easy to extend with new assessment scripts

## Installation

1. Clone the repository:
   ```
   git clone <repository-url>
   cd Universe42/bash_command
   ```

2. Build the project:
   ```
   make
   ```

## Usage

Run the CLI controller:

```
./bin/assessment-cli
```

Use keyboard navigation:
- Arrow keys or `j`/`k` to navigate up and down
- Number keys (1-9) to select options directly
- Enter to execute the selected script
- `q` to quit

## Available Scripts

The CLI automatically discovers and lists all bash scripts in the `scripts/` directory:

- `check_norminette.sh` - Check project files for norminette compliance
- `memory_check.sh` - Check for memory leaks using valgrind
- `compile_test.sh` - Test compilation with different flags
- `header_check.sh` - Verify header files for proper structure
- `style_check.sh` - Check coding style beyond norminette

## Creating New Scripts

Add new assessment scripts in the `scripts/` directory:

1. Create a new `.sh` file in the `scripts/` directory
2. Make it executable (`chmod +x your_script.sh`)
3. Add a descriptive comment as the first line of the script
4. Use underscores in the filename for better readability
5. Use the `report_progress` function to update the progress bar:
   ```bash
   function report_progress {
       if [ -n "$PROGRESS_FD" ]; then
           echo "$1" >&$PROGRESS_FD
       fi
   }
   
   report_progress 50  # Update to 50%
   ```

## Contributing

Feel free to contribute new scripts or improvements to the CLI interface!


- [] ERROR : `*` regexp in --> char	*ft_hex_to_str(unsigned long int num, char *str, size_t len)
