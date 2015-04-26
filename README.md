# OpenOS-mods
Modifications and additions to OpenComputers OpenOS

Noteable changes:

    Persistence of aliases
    Persistence of environment variables
    File size switches for ls command.  
    Syntax highlighting version of /bin/edit.lua (cedit).  
    Inverted blinking cursor to term (for cedit).  


cedit - syntax highlighting editor:

    needs updated /bin/term.lua for inverted blinking cursor
    keyboard shortcuts:
      ctrl + g    = goto line
      ctrl + left = goto previous word/punct
      ctrl + next = goto next word/punct
