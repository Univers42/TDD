/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    script_manager.h                                    :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#ifndef SCRIPT_MANAGER_H
#define SCRIPT_MANAGER_H

#define MAX_SCRIPTS 50
#define MAX_PATH_LENGTH 256
#define MAX_NAME_LENGTH 64
#define MAX_DESC_LENGTH 256

// Callback function type for progress updates
typedef void (*progress_callback)(int percentage);

// Structure to hold script information
typedef struct {
    char path[MAX_PATH_LENGTH];
    char name[MAX_NAME_LENGTH];
    char description[MAX_DESC_LENGTH];
} ScriptInfo;

// Initialize the script manager
void script_manager_init(void);

// Clean up script manager resources
void script_manager_cleanup(void);

// Get total number of available scripts
int script_manager_get_count(void);

// Get script info by index
ScriptInfo script_manager_get_by_index(int index);

// Execute script by index, with callback for progress updates and optional parameters
// Returns:
//   0 for success
//   < 0 for warning
//   > 0 for error
int script_manager_execute(int index, progress_callback cb, const char *params);

// Get the current log file path (NULL if no error occurred)
const char* script_manager_get_log_file(void);

#endif /* SCRIPT_MANAGER_H */
