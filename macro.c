/* GNU ed - The GNU line editor - Macro system.
   Copyright (C) 2025 Macro Extension.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

#include "ed.h"

static macro_t *macro_list = NULL;

/* Load macros from a configuration file */
bool load_macros( const char * const filename )
  {
  FILE *fp;
  char line[512];
  char *seq, *cmd, *colon_pos;
  macro_t *new_macro;

  if( !filename || !*filename ) return true;  /* no filename is ok */
  
  fp = fopen( filename, "r" );
  if( !fp ) return true;  /* file not existing is ok */

  while( fgets( line, sizeof(line), fp ) )
    {
    /* Skip comments and empty lines */
    if( line[0] == '#' || line[0] == '\n' || line[0] == '\r' ) continue;

    /* Remove trailing newline */
    line[strcspn(line, "\n\r")] = 0;

    /* Find the colon separator */
    colon_pos = strchr( line, ':' );
    if( !colon_pos ) continue;

    *colon_pos = 0;
    seq = line;
    cmd = colon_pos + 1;

    /* Skip leading spaces */
    while( *seq == ' ' || *seq == '\t' ) seq++;
    while( *cmd == ' ' || *cmd == '\t' ) cmd++;

    /* Skip if either sequence or command is empty */
    if( !*seq || !*cmd ) continue;

    /* Convert \e to actual ESC character in sequence */
    if( seq[0] == '\\' && seq[1] == 'e' )
      {
      seq[0] = '\033';  /* ESC character */
      memmove( seq + 1, seq + 2, strlen(seq + 2) + 1 );
      }

    /* Create new macro */
    new_macro = malloc( sizeof(macro_t) );
    if( !new_macro ) 
      {
      fclose( fp );
      return false;
      }

    new_macro->sequence = malloc( strlen(seq) + 1 );
    new_macro->command = malloc( strlen(cmd) + 1 );
    if( !new_macro->sequence || !new_macro->command )
      {
      free( new_macro->sequence );
      free( new_macro->command );
      free( new_macro );
      fclose( fp );
      return false;
      }

    strcpy( new_macro->sequence, seq );
    strcpy( new_macro->command, cmd );
    new_macro->next = macro_list;
    macro_list = new_macro;
    }

  fclose( fp );
  return true;
  }

/* Find a macro by its escape sequence */
const char * find_macro( const char * const sequence )
  {
  macro_t *current = macro_list;
  
  while( current )
    {
    if( strcmp( current->sequence, sequence ) == 0 )
      return current->command;
    current = current->next;
    }
  
  return NULL;
  }

/* Free all macros */
void free_macros( void )
  {
  macro_t *current = macro_list;
  macro_t *next;
  
  while( current )
    {
    next = current->next;
    free( current->sequence );
    free( current->command );
    free( current );
    current = next;
    }
  
  macro_list = NULL;
  }

/* Expand macros in a command line starting with escape sequences */
const char * expand_macro_line( const char * const input_line )
  {
  static char * expanded_buf = 0;
  static int expanded_bufsz = 0;
  const char * macro_cmd;
  
  /* Check if line starts with escape character */
  if( !input_line || input_line[0] != '\033' /* ESC */ )
    return input_line;  /* No macro expansion needed */
  
  /* Find the macro sequence (everything after ESC until newline or end) */
  const char * seq_start = input_line + 1;  /* Skip ESC */
  const char * seq_end = seq_start;
  
  /* Find end of sequence (up to first space, newline, or end of string) */
  while( *seq_end && *seq_end != ' ' && *seq_end != '\t' && 
         *seq_end != '\n' && *seq_end != '\r' )
    seq_end++;
  
  /* Extract the sequence */
  size_t seq_len = seq_end - seq_start;
  char sequence[64];
  if( seq_len >= sizeof(sequence) ) return input_line;  /* Sequence too long */
  
  strncpy( sequence, seq_start, seq_len );
  sequence[seq_len] = 0;
  
  /* Look up the macro */
  macro_cmd = find_macro( sequence );
  if( !macro_cmd ) return input_line;  /* Macro not found */
  
  /* Simple safety check */
  if( !macro_cmd || strlen(macro_cmd) == 0 ) return input_line;
  
  /* Check for reasonable command length to prevent buffer issues */
  int cmd_len = strlen( macro_cmd );
  if( cmd_len > 1024 ) return input_line;  /* Command too long */
  
  if( !resize_buffer( &expanded_buf, &expanded_bufsz, cmd_len + 2 ) )
    return input_line;
  
  /* Copy the macro command and ensure proper termination */
  strcpy( expanded_buf, macro_cmd );
  /* Add newline if not present */
  if( cmd_len > 0 && expanded_buf[cmd_len - 1] != '\n' )
    {
    expanded_buf[cmd_len] = '\n';
    expanded_buf[cmd_len + 1] = '\0';
    }
  
  return expanded_buf;
  }
