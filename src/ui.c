/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    ui.c                                                :+:      :+:    :+:   */
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
#include <sys/ioctl.h>
#include "ui.h"
#include "script_manager.h"

// Terminal dimensions
static int term_width = 80;
static int term_height = 24;

// Get terminal size
static void update_terminal_size() {
    struct winsize w;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) != -1) {
        term_width = w.ws_col;
        term_height = w.ws_row;
    }
}

void ui_init(void) {
    // Get initial terminal size
    update_terminal_size();
    
    // Hide cursor
    printf("\033[?25l");
    
    // Set up terminal for interactive use
    system("stty -echo");
    system("stty raw");
}

void ui_cleanup(void) {
    // Restore cursor
    printf("\033[?25h");
    
    // Reset terminal
    system("stty echo");
    system("stty cooked");
}

void ui_clear_screen(void) {
    printf("\033[2J\033[H");
    fflush(stdout);
}

void ui_move_cursor(int x, int y) {
    printf("\033[%d;%dH", y, x);
    fflush(stdout);
}

void ui_animated_text(const char *text, int delay_ms) {
    for (size_t i = 0; i < strlen(text); i++) {
        putchar(text[i]);
        fflush(stdout);
        usleep(delay_ms * 1000);
    }
}

void ui_show_welcome(void) {
    ui_clear_screen();
    
    // Calculate center position
    int start_y = term_height / 2 - 3;
    int start_x = (term_width - 42) / 2;
    
    ui_move_cursor(start_x, start_y);
    printf("%s", COLOR_BOLD);
    ui_animated_text("┌────────────────────────────────────┐", 5);
    
    ui_move_cursor(start_x, start_y + 1);
    ui_animated_text("│         ", 5);
    printf("%s", COLOR_CYAN);
    ui_animated_text("42 Project Assessment", 10);
    printf("%s", COLOR_BOLD);
    ui_animated_text("        │", 5);
    
    ui_move_cursor(start_x, start_y + 2);
    ui_animated_text("│          ", 5);
    printf("%s", COLOR_MAGENTA);
    ui_animated_text("Interactive Controller", 10);
    printf("%s", COLOR_BOLD);
    ui_animated_text("        │", 5);
    
    ui_move_cursor(start_x, start_y + 3);
    printf("%s", COLOR_BOLD);
    ui_animated_text("└────────────────────────────────────┘", 5);
    
    printf("%s", COLOR_RESET);
    
    // Wait a moment
    sleep(1);
}

void ui_draw_menu(void) {
    update_terminal_size();
    ui_clear_screen();
    
    // Header - ensure it's centered
    int header_width = 45; // Width of the box
    int start_x = (term_width - header_width) / 2;
    
    // Move to start position
    ui_move_cursor(start_x, 1);
    printf("%s%s╔═══════════════════════════════════════════╗%s", COLOR_BOLD, COLOR_CYAN, COLOR_RESET);
    
    ui_move_cursor(start_x, 2);
    printf("%s%s║            ASSESSMENT TOOLBOX             ║%s", COLOR_BOLD, COLOR_CYAN, COLOR_RESET);
    
    ui_move_cursor(start_x, 3);
    printf("%s%s╚═══════════════════════════════════════════╝%s", COLOR_BOLD, COLOR_CYAN, COLOR_RESET);
    
    // Instructions - also centered
    ui_move_cursor((term_width - 56) / 2, 5); // Centered instructions
    printf("%sUse arrow keys to navigate, Enter to select, 'q' to quit%s", COLOR_BOLD, COLOR_RESET);
    
    // Get the longest menu item to calculate padding
    int max_item_length = 0;
    int script_count = script_manager_get_count();
    for (int i = 0; i < script_count; i++) {
        ScriptInfo script = script_manager_get_by_index(i);
        int item_length = snprintf(NULL, 0, "%d. %s - %s", i+1, script.name, script.description);
        if (item_length > max_item_length)
            max_item_length = item_length;
    }
    
    // Center the menu items
    int menu_start_x = (term_width - max_item_length) / 2;
    if (menu_start_x < 5) menu_start_x = 5; // Minimum margin
    
    // List available scripts in a single column with centered alignment
    for (int i = 0; i < script_count; i++) {
        ScriptInfo script = script_manager_get_by_index(i);
        
        ui_move_cursor(menu_start_x, 7 + i);
        printf("%s%d.%s %s%s%s - %s", 
            COLOR_YELLOW, i+1, COLOR_RESET,
            COLOR_BOLD, script.name, COLOR_RESET,
            script.description);
    }
    
    // Move cursor to a consistent position after the menu
    ui_move_cursor(0, 7 + script_count + 1);
    fflush(stdout);
}

// New function to get additional parameters for a script
char* ui_get_script_params(ScriptInfo* script) {
    static char params[256]; // Static buffer for parameters
    params[0] = '\0'; // Initialize to empty string
    
    // Check if this script needs parameters
    if (strstr(script->name, "Memory check") != NULL || 
        strstr(script->name, "Compile test") != NULL ||
        strstr(script->name, "Check functions") != NULL) {
        
        // Center position for the input prompt
        update_terminal_size();
        int start_x = (term_width - 60) / 2;
        if (start_x < 2) start_x = 2;
        
        // Show prompt
        ui_clear_screen();
        ui_move_cursor(start_x, 3);
        printf("%sEnter target program or path:%s ", COLOR_BOLD, COLOR_RESET);
        
        // Reset terminal for input
        ui_cleanup();
        
        // Get user input
        if (fgets(params, sizeof(params), stdin) != NULL) {
            // Remove trailing newline
            char *newline = strchr(params, '\n');
            if (newline) *newline = '\0';
        }
        
        // Restore terminal settings
        ui_init();
    }
    
    return params;
}

void ui_draw_running_script(ScriptInfo* script) {
    ui_clear_screen();
    update_terminal_size();
    
    // Center header just like the main menu
    int header_width = 45;
    int start_x = (term_width - header_width) / 2;
    
    // Header box
    ui_move_cursor(start_x, 1);
    printf("%s%s╔═══════════════════════════════════════════╗%s", COLOR_BOLD, COLOR_BLUE, COLOR_RESET);
    
    ui_move_cursor(start_x, 2);
    printf("%s%s║              RUNNING SCRIPT               ║%s", COLOR_BOLD, COLOR_BLUE, COLOR_RESET);
    
    ui_move_cursor(start_x, 3);
    printf("%s%s╚═══════════════════════════════════════════╝%s", COLOR_BOLD, COLOR_BLUE, COLOR_RESET);
    
    // Center align the content
    ui_move_cursor(start_x, 5);
    printf("%sExecuting:%s %s%s%s", COLOR_BOLD, COLOR_RESET, COLOR_CYAN, script->name, COLOR_RESET);
    
    ui_move_cursor(start_x, 7);
    printf("%sDescription:%s %s", COLOR_BOLD, COLOR_RESET, script->description);
    
    // Center the progress bar
    ui_move_cursor(start_x, 9);
    printf("%sProgress: [%s", COLOR_BOLD, COLOR_RESET);
    for (int i = 0; i < 30; i++) {
        printf(" ");
    }
    printf("%s]%s   0%%", COLOR_BOLD, COLOR_RESET);
    
    fflush(stdout);
}

void ui_update_progress(int percentage) {
    // Cap percentage between 0 and 100
    if (percentage < 0) percentage = 0;
    if (percentage > 100) percentage = 100;
    
    // Get centered position like in ui_draw_running_script
    update_terminal_size();
    int header_width = 45;
    int start_x = (term_width - header_width) / 2;
    
    // Calculate filled positions in the progress bar
    int filled = (percentage * 30) / 100;
    
    // Move cursor to progress bar position
    ui_move_cursor(start_x + 10, 9);  // +10 to account for "Progress: ["
    
    // Draw progress bar
    for (int i = 0; i < 30; i++) {
        if (i < filled) {
            printf("%s█%s", COLOR_GREEN, COLOR_RESET);
        } else {
            printf(" ");
        }
    }
    printf("%s]%s %3d%%", COLOR_BOLD, COLOR_RESET, percentage);
    
    fflush(stdout);
}

void ui_show_result(int result, ScriptInfo* script) {
    // Mark parameter as intentionally unused
    (void)script;
    
    // Get centered position like other elements
    update_terminal_size();
    int header_width = 45;
    int start_x = (term_width - header_width) / 2;
    
    // Move cursor to position below progress bar
    ui_move_cursor(start_x, 11);
    
    printf("%sResult:%s ", COLOR_BOLD, COLOR_RESET);
    
    if (result == 0) {
        printf("%s✅ PASS%s Script executed successfully!", COLOR_GREEN, COLOR_RESET);
    } else if (result < 0) {
        printf("%s⚠️  WARNING%s Script completed with warnings.", COLOR_YELLOW, COLOR_RESET);
    } else {
        printf("%s❌ FAIL%s Script failed with error code %d", COLOR_RED, COLOR_RESET, result);
        
        // Check if there's a log file
        const char* log_file = script_manager_get_log_file();
        if (log_file) {
            // Move cursor to show log file info
            ui_move_cursor(start_x, 13);
            printf("Detailed log saved to: %s%s%s", COLOR_CYAN, log_file, COLOR_RESET);
            
            // Show how to access the file
            ui_move_cursor(start_x, 14);
            printf("View log with: %scat %s%s", COLOR_BOLD, log_file, COLOR_RESET);
        }
    }
    
    // Show prompt centered
    int prompt_y = (result != 0 && script_manager_get_log_file()) ? 16 : 13;
    ui_move_cursor(start_x, prompt_y);
    printf("Press any key to return to menu...");
    fflush(stdout);
    getchar(); // Wait for keypress
}
