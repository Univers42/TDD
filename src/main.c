/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    main.c                                              :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include "ui.h"
#include "input.h"
#include "script_manager.h"

// Global flag for clean exit
volatile sig_atomic_t running = 1;

// Signal handler for clean exit
void handle_signal(int sig) {
    (void)sig; // Mark parameter as intentionally unused
    running = 0;
}

int main(int argc, char *argv[]) {
    // Mark parameters as intentionally unused
    (void)argc;
    (void)argv;
    
    // Set up signal handlers
    signal(SIGINT, handle_signal);
    
    // Initialize components
    ui_init();
    input_init();
    script_manager_init();
    
    // Welcome animation
    ui_show_welcome();
    
    // Main program loop
    while (running) {
        ui_draw_menu();
        int selection = input_get_menu_selection();
        
        if (selection == -1) {
            // Exit requested
            break;
        } else if (selection >= 0) {
            ScriptInfo script = script_manager_get_by_index(selection);
            if (script.path[0] != '\0') {
                // Get additional parameters if needed
                char *params = ui_get_script_params(&script);
                
                ui_draw_running_script(&script);
                int result = script_manager_execute(selection, ui_update_progress, params);
                ui_show_result(result, &script);
            }
        }
    }
    
    // Clean up and exit
    ui_cleanup();
    input_cleanup();
    script_manager_cleanup();
    
    return 0;
}
