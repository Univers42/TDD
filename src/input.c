/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    input.c                                             :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#include <stdio.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include "input.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "script_manager.h"
#include "ui.h" // Add this include for ui_move_cursor function

// Terminal settings to restore on exit
static struct termios orig_termios;

void input_init(void) {
    // Save original terminal settings
    tcgetattr(STDIN_FILENO, &orig_termios);
    
    // Set terminal to raw mode
    struct termios raw = orig_termios;
    raw.c_lflag &= ~(ECHO | ICANON);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void input_cleanup(void) {
    // Restore original terminal settings
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

int input_read_char(void) {
    int c = getchar();
    
    // Handle arrow keys (which start with escape sequence)
    if (c == 27) {
        // Skip the '[' character
        getchar();
        
        // Get the actual arrow key code
        switch (getchar()) {
            case 'A': return 'k'; // Up arrow -> k
            case 'B': return 'j'; // Down arrow -> j
            case 'C': return 'l'; // Right arrow -> l
            case 'D': return 'h'; // Left arrow -> h
            default: return c;
        }
    }
    
    return c;
}

int input_get_menu_selection(void) {
    int script_count = script_manager_get_count();
    int current_selection = 0;
    int key;
    
    // Calculate menu position based on terminal width
    struct winsize w;
    int menu_start_x = 5;
    
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) != -1) {
        // Get header position using the same calculation as in ui.c
        int header_width = 45;
        int start_x = (w.ws_col - header_width) / 2;
        menu_start_x = start_x + 2; // Position arrow slightly left of the menu items
    }
    
    // Place initial selection arrow
    ui_move_cursor(menu_start_x, 7);
    printf("%s➤%s", "\033[32m", "\033[0m");
    fflush(stdout);
    
    // Save cursor position after menu
    int end_y = 7 + script_count + 1;
    
    // Get user input
    while (1) {
        key = input_read_char();
        
        // Clear current arrow
        ui_move_cursor(menu_start_x, 7 + current_selection);
        printf(" ");
        
        // Handle navigation keys
        switch (key) {
            case 'k': // Up
            case 'K':
                if (current_selection > 0) {
                    current_selection--;
                } else {
                    // Wrap to bottom
                    current_selection = script_count - 1;
                }
                break;
                
            case 'j': // Down
            case 'J':
                if (current_selection < script_count - 1) {
                    current_selection++;
                } else {
                    // Wrap to top
                    current_selection = 0;
                }
                break;
                
            case 'h': // Left - do nothing in single column layout
            case 'H':
            case 'l': // Right - do nothing in single column layout
            case 'L':
                break;
                
            case '\n': // Enter key
            case '\r':
                // Move cursor to end position before returning
                ui_move_cursor(0, end_y);
                return current_selection;
                
            case 'q': // Quit
            case 'Q':
            case 3: // Ctrl+C
                // Move cursor to end position before returning
                ui_move_cursor(0, end_y);
                return -1;
                
            case '1': case '2': case '3': case '4': case '5':
            case '6': case '7': case '8': case '9':
                // Number keys 1-9 for direct selection
                int num = key - '0' - 1; // Convert to 0-based index
                if (num < script_count) {
                    // Move cursor to end position before returning
                    ui_move_cursor(0, end_y);
                    return num;
                }
                break;
        }
        
        // Show arrow at the new selection
        ui_move_cursor(menu_start_x, 7 + current_selection);
        printf("%s➤%s", "\033[32m", "\033[0m");
        fflush(stdout);
    }
}
