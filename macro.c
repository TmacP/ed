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
  
  /* Check for repeat pattern: ESC + number + character */
  const char * p = input_line + 1;  /* Skip ESC */
  if( isdigit( *p ) )
    {
    /* Parse the number */
    int repeat_count = 0;
    while( isdigit( *p ) )
      {
      repeat_count = repeat_count * 10 + (*p - '0');
      p++;
      }
    
    /* Check if there's a character to repeat */
    if( *p && *p != '\n' && *p != '\r' )
      {
      char repeat_char = *p;
      p++; /* Move past the character */
      
      /* Calculate buffer size needed */
      int needed_size = repeat_count + 4;  /* +1 for 'i', +1 for '\n', +1 for '.', +1 for '\n' */
      const char * rest = p;
      while( *rest && *rest != '\n' && *rest != '\r' ) rest++;
      needed_size += (rest - p) + 1;  /* additional chars + null terminator */
      
      if( !resize_buffer( &expanded_buf, &expanded_bufsz, needed_size ) )
        return input_line;
      
      /* Build the insert command: i + repeated chars + additional chars + newline + . + newline */
      expanded_buf[0] = 'i';
      expanded_buf[1] = '\0';
      
      /* Add the repeated characters */
      for( int i = 0; i < repeat_count; i++ )
        {
        size_t len = strlen( expanded_buf );
        expanded_buf[len] = repeat_char;
        expanded_buf[len + 1] = '\0';
        }
      
      /* Add any remaining characters from the input */
      while( p < rest )
        {
        size_t len = strlen( expanded_buf );
        expanded_buf[len] = *p;
        expanded_buf[len + 1] = '\0';
        p++;
        }
      
      /* Add the terminating newline, dot, and newline */
      strcat( expanded_buf, "\n.\n" );
      
      return expanded_buf;
      }
    }
  
  /* Not a repeat pattern, check for regular macro */
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
  
  /* Expand the macro command */
  int cmd_len = strlen( macro_cmd );
  const char * args = seq_end;
  
  /* Skip leading whitespace in args */
  while( *args == ' ' || *args == '\t' ) args++;
  
  int args_len = strlen( args );
  int total_len = cmd_len + args_len + 1;
  
  if( !resize_buffer( &expanded_buf, &expanded_bufsz, total_len ) )
    return input_line;
  
  /* Just return the macro command as-is - let ed handle % substitution */
  strcpy( expanded_buf, macro_cmd );
  
  return expanded_buf;
  }
