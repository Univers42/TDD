/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    script_manager.c                                    :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h> 
#include <fcntl.h>
#include <time.h>
#include "script_manager.h"
#include <ctype.h>

// Array of available scripts
static ScriptInfo scripts[MAX_SCRIPTS];
static int script_count = 0;

// Directory where scripts are stored
static const char *script_dir = "/home/dyl-syzygy/Universe42/bash_command/scripts";

// Log directory for script output when errors occur
static char log_dir[MAX_PATH_LENGTH] = {0};
static char current_log_file[MAX_PATH_LENGTH] = {0};

// Create log directory if it doesn't exist
static void ensure_log_directory(void) {
    // Create the base log directory path
    snprintf(log_dir, sizeof(log_dir), "%s/logs", getenv("HOME") ? getenv("HOME") : ".");
    
    // Create directory if it doesn't exist
    struct stat st = {0};
    if (stat(log_dir, &st) == -1) {
        mkdir(log_dir, 0755);
    }
}

// Extract script name from filename
static void extract_script_name(const char *filename, char *name) {
    // Copy filename without extension
    strcpy(name, filename);
    
    // Replace underscores with spaces
    char *ptr = name;
    while (*ptr) {
        if (*ptr == '_')
            *ptr = ' ';
        ptr++;
    }
    
    // Remove .sh extension if present
    ptr = strstr(name, ".sh");
    if (ptr) *ptr = '\0';
    
    // Capitalize first letter
    if (name[0] >= 'a' && name[0] <= 'z')
        name[0] = name[0] - 32;
}

// Read first comment line as description
static void extract_script_description(const char *path, char *description) {
    FILE *file = fopen(path, "r");
    if (!file) {
        strcpy(description, "No description available");
        return;
    }
    
    char line[MAX_DESC_LENGTH];
    if (fgets(line, sizeof(line), file)) {
        // Skip the shebang line if present
        if (strncmp(line, "#!", 2) == 0) {
            // If first line is shebang, get the next line instead
            if (fgets(line, sizeof(line), file) == NULL) {
                strcpy(description, "No description available");
                fclose(file);
                return;
            }
        }
        
        // Remove leading "#" or "# " if present
        char *desc_start = line;
        if (line[0] == '#') {
            desc_start++;
            if (*desc_start == ' ')
                desc_start++;
        }
        
        // Remove trailing newline
        char *newline = strchr(desc_start, '\n');
        if (newline) *newline = '\0';
        
        // Copy description
        strncpy(description, desc_start, MAX_DESC_LENGTH - 1);
        description[MAX_DESC_LENGTH - 1] = '\0';
    } else {
        strcpy(description, "No description available");
    }
    
    fclose(file);
}

void script_manager_init(void) {
    // Create log directory
    ensure_log_directory();
    
    DIR *dir;
    struct dirent *entry;
    struct stat st;
    char path[MAX_PATH_LENGTH];
    
    // Open scripts directory
    dir = opendir(script_dir);
    if (!dir) {
        fprintf(stderr, "Error: Cannot open scripts directory\n");
        return;
    }
    
    // Scan for .sh files
    script_count = 0;
    while ((entry = readdir(dir)) != NULL && script_count < MAX_SCRIPTS) {
        // Skip hidden files and directories
        if (entry->d_name[0] == '.')
            continue;
        
        // Check if file ends with .sh
        size_t len = strlen(entry->d_name);
        if (len <= 3 || strcmp(entry->d_name + len - 3, ".sh") != 0)
            continue;
        
        // Calculate combined path length to prevent buffer overflow
        size_t dir_len = strlen(script_dir);
        size_t name_len = strlen(entry->d_name);
        size_t total_len = dir_len + 1 + name_len; // +1 for the "/" separator
        
        // Skip if path would be too long
        if (total_len >= MAX_PATH_LENGTH) {
            fprintf(stderr, "Warning: Path too long for script: %s/%s\n", script_dir, entry->d_name);
            continue;
        }
        
        // Safely construct the path using explicit string operations instead of snprintf
        strcpy(path, script_dir);
        strcat(path, "/");
        strcat(path, entry->d_name);
        
        // Check if it's a regular file
        if (stat(path, &st) == 0 && S_ISREG(st.st_mode)) {
            // Add to script list
            strncpy(scripts[script_count].path, path, MAX_PATH_LENGTH - 1);
            scripts[script_count].path[MAX_PATH_LENGTH - 1] = '\0';
            
            // Extract name from filename
            extract_script_name(entry->d_name, scripts[script_count].name);
            
            // Extract description from first comment line
            extract_script_description(path, scripts[script_count].description);
            
            script_count++;
        }
    }
    
    closedir(dir);
}

void script_manager_cleanup(void) {
    // Nothing to clean up currently
}

int script_manager_get_count(void) {
    return script_count;
}

ScriptInfo script_manager_get_by_index(int index) {
    // Initialize all fields of the struct to prevent compiler warning
    static ScriptInfo empty = {
        .path = {0},
        .name = {0},
        .description = {0}
    };
    
    if (index >= 0 && index < script_count) {
        return scripts[index];
    }
    
    return empty;
}

int script_manager_execute(int index, progress_callback cb, const char *params) {
    if (index < 0 || index >= script_count) {
        return 1; // Error: invalid index
    }
    
    // Reset the current log file path
    current_log_file[0] = '\0';
    
    // Create pipes for output and progress
    int output_pipe[2];
    int progress_pipe[2];
    
    if (pipe(output_pipe) < 0 || pipe(progress_pipe) < 0) {
        return 2; // Error: couldn't create pipes
    }
    
    // Fork process
    pid_t pid = fork();
    
    if (pid < 0) {
        return 3; // Error: fork failed
    } else if (pid == 0) {
        // Child process
        
        // Close read ends of pipes
        close(output_pipe[0]);
        close(progress_pipe[0]);
        
        // Redirect stdout and stderr to the output pipe
        dup2(output_pipe[1], STDOUT_FILENO);
        dup2(output_pipe[1], STDERR_FILENO);
        
        // Export progress pipe fd to environment
        char progress_fd_str[16];
        snprintf(progress_fd_str, sizeof(progress_fd_str), "%d", progress_pipe[1]);
        setenv("PROGRESS_FD", progress_fd_str, 1);
        
        // Execute the script with parameters if provided
        if (params && params[0] != '\0') {
            execl("/bin/bash", "bash", scripts[index].path, params, NULL);
        } else {
            execl("/bin/bash", "bash", scripts[index].path, NULL);
        }
        
        // If execl returns, it failed
        fprintf(stderr, "Failed to execute script\n");
        exit(4);
    }
    
    // Parent process
    
    // Close write ends of pipes
    close(output_pipe[1]);
    close(progress_pipe[1]);
    
    // Set output pipe to non-blocking
    fcntl(output_pipe[0], F_SETFL, O_NONBLOCK);
    fcntl(progress_pipe[0], F_SETFL, O_NONBLOCK);
    
    // Buffer for reading from pipes
    char buffer[256];
    int progress = 0;
    int status;
    
    // Capture script output for logging
    char output_buffer[65536] = {0};  // 64KB buffer for script output
    size_t output_size = 0;
    
    // Call the progress callback with initial 0%
    if (cb) cb(0);
    
    // Monitor pipes until script completes
    while (1) {
        // Check for progress updates
        ssize_t progress_bytes = read(progress_pipe[0], buffer, sizeof(buffer)-1);
        if (progress_bytes > 0) {
            buffer[progress_bytes] = '\0';
            progress = atoi(buffer);
            if (cb) cb(progress);
        }
        
        // Read script output and store it in the output buffer
        ssize_t output_bytes;
        while ((output_bytes = read(output_pipe[0], buffer, sizeof(buffer)-1)) > 0) {
            // Make sure we don't overflow the output buffer
            if (output_size + output_bytes < sizeof(output_buffer)) {
                buffer[output_bytes] = '\0';
                memcpy(output_buffer + output_size, buffer, output_bytes);
                output_size += output_bytes;
            }
        }
        
        // Check if child process has finished
        int result = waitpid(pid, &status, WNOHANG);
        if (result == pid) {
            break;  // Script completed
        }
        
        // Small sleep to prevent CPU hogging
        usleep(100000);  // 100ms
    }
    
    // Close read ends of pipes
    close(output_pipe[0]);
    close(progress_pipe[0]);
    
    // Call the progress callback with final 100%
    if (cb) cb(100);
    
    // Get the script exit code
    int exit_code = 0;
    if (WIFEXITED(status)) {
        exit_code = WEXITSTATUS(status);
    } else {
        exit_code = 5; // Error: script terminated abnormally
    }
    
    // If the script failed, save the output to a log file
    if (exit_code != 0) {
        // Create a unique log filename with timestamp
        time_t now = time(NULL);
        struct tm *tm_info = localtime(&now);
        char timestamp[32];
        strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", tm_info);
        
        // Create a safer name for the log file based on script name (limit length)
        char safe_name[64] = {0};
        strncpy(safe_name, scripts[index].name, 30); // Limit the script name length
        safe_name[30] = '\0'; // Ensure null termination
        
        // Replace any spaces or special characters with underscore
        for (char *ptr = safe_name; *ptr; ptr++) {
            if (!isalnum(*ptr)) {
                *ptr = '_';
            }
        }
        
        // Build the log path step by step to avoid format truncation warnings
        if (strlen(log_dir) + 1 + strlen(timestamp) + 1 + strlen(safe_name) + 4 < MAX_PATH_LENGTH) {
            // Start with the log directory
            strcpy(current_log_file, log_dir);
            
            // Add path separator
            strcat(current_log_file, "/");
            
            // Add timestamp
            strcat(current_log_file, timestamp);
            
            // Add underscore
            strcat(current_log_file, "_");
            
            // Add sanitized script name
            strcat(current_log_file, safe_name);
            
            // Add extension
            strcat(current_log_file, ".log");
            
            // Write output to the log file
            FILE *log_file = fopen(current_log_file, "w");
            if (log_file) {
                fprintf(log_file, "===== %s =====\n\n", scripts[index].name);
                fprintf(log_file, "Command: %s\n\n", scripts[index].path);
                fprintf(log_file, "Exit code: %d\n\n", exit_code);
                fprintf(log_file, "Output:\n%s\n", output_buffer);
                fclose(log_file);
            } else {
                // Reset log file path if we couldn't create the file
                current_log_file[0] = '\0';
            }
        } else {
            // Path would be too long, so don't try to create a log file
            fprintf(stderr, "Warning: Log file path would be too long, skipping log creation\n");
            current_log_file[0] = '\0';
        }
    }
    
    return exit_code;
}

// Get current log file path (empty if no error occurred)
const char* script_manager_get_log_file(void) {
    return current_log_file[0] != '\0' ? current_log_file : NULL;
}
