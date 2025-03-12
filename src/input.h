/* **************************************************************************** */
/*                                                                              */
/*                                                         :::      ::::::::    */
/*    input.h                                             :+:      :+:    :+:   */
/*                                                     +:+ +:+         +:+      */
/*    By: dyl-syzygy <dyl-syzygy@student.42.fr>      +#+  +:+       +#+         */
/*                                                 +#+#+#+#+#+   +#+            */
/*    Created: 2025/03/12 13:08:31 by dyl-syzygy        #+#    #+#              */
/*    Updated: 2025/03/12 13:08:31 by dyl-syzygy       ###   ########.fr        */
/*                                                                              */
/* **************************************************************************** */

#ifndef INPUT_H
#define INPUT_H

// Initialize input handling
void input_init(void);

// Clean up input resources
void input_cleanup(void);

// Get menu selection from user
// Returns:
//   -1 for exit request
//   >= 0 for valid selection
int input_get_menu_selection(void);

// Read a single character without echo
int input_read_char(void);

#endif /* INPUT_H */
