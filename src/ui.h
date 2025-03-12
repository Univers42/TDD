/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    ui.h                                                :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#ifndef UI_H
#define UI_H

#include "script_manager.h"

// UI color definitions
#define COLOR_RESET   "\x1b[0m"
#define COLOR_RED     "\x1b[31m"
#define COLOR_GREEN   "\x1b[32m"
#define COLOR_YELLOW  "\x1b[33m"
#define COLOR_BLUE    "\x1b[34m"
#define COLOR_MAGENTA "\x1b[35m"
#define COLOR_CYAN    "\x1b[36m"
#define COLOR_WHITE   "\x1b[37m"
#define COLOR_BOLD    "\x1b[1m"

// Initialize the UI system
void ui_init(void);

// Clean up UI resources
void ui_cleanup(void);

// Show welcome animation
void ui_show_welcome(void);

// Draw the main menu
void ui_draw_menu(void);

// Draw running script UI
void ui_draw_running_script(ScriptInfo* script);

// Update progress bar for script execution
void ui_update_progress(int percentage);

// Show script execution result
void ui_show_result(int result, ScriptInfo* script);

// Clear screen
void ui_clear_screen(void);

// Move cursor to position
void ui_move_cursor(int x, int y);

// Draw animated text
void ui_animated_text(const char *text, int delay_ms);

// Get additional parameters for a script (returns a static buffer)
char* ui_get_script_params(ScriptInfo* script);

#endif /* UI_H */
