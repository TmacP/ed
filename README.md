# Tristen's Fork of GNU ed

## Implemented Features

- **Macros:** Press `ESC` to trigger shortcuts for commands.  
    Example:  
    - `ESC gs` → `!git status`
    - `ESC gd` → `!git diff %`
    - `ESC ga` → `!git add %`
    - `ESC gc` → `!git commit`
    - `ESC ls` → `!ls -la`
    
    Configure macros in `~/.ed_macros` using format: `sequence:command`

- **Quick Indentation:** In insert mode, press `ESC` followed by a number to insert that many spaces.  
    Example:  
    - `ESC 4` inserts 4 spaces for indentation
    - `ESC 8` inserts 8 spaces
    
    Perfect for quick indentation without repeatedly pressing spacebar.

- **Interactive Line Editing:** Press `ESC a` to edit the current line interactively.
    - `←` `→` arrow keys to move cursor character by character
    - `Ctrl+B` to move back one word
    - `Ctrl+F` to move forward one word
    - `Backspace` to delete previous character
    - `Ctrl+D` to delete character at cursor
    - Type normally to insert characters
    - `Enter` to save changes
    - `ESC` to cancel without saving
    
    Simple, clean line editing that integrates perfectly with ed's undo system!

- **Page Navigation:** Enhanced page navigation commands.
    - `z` for page down (default ed behavior)
    - `Z` for page up (new feature)
    
    Navigate through large files more efficiently.

