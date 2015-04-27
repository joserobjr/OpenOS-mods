# OpenOS-mods
Modifications and additions to OpenComputers OpenOS

Noteable changes:

    Persistence of aliases.  
    Persistence of environment variables.  
    File size switches for ls command.  
    Syntax highlighter library.
    Syntax highlighting version of /bin/edit.lua (cedit).  
    Syntax highlighting version of /bin/more.lua (hl).  
    Inverted blinking cursor to term (for cedit).  


cedit - syntax highlighting editor:

    reads keybindings and ui colors from /etc/cedit.cfg
    needs updated /bin/term.lua for inverted blinking cursor.
    needs new /lib/highlighter.lua for syntax highlighting.
    new keybindings:
      ctrl + g    = goto line
      ctrl + left = goto previous word/punct
      ctrl + next = goto next word/punct
      ctrl + home = goto top line
      ctrl + end  = goto last line
      ctrl + up   = scoll up one line, with cursor in-place
      ctrl + down = scroll down one line, with cursor in-place

hl - syntax highlighting more:

    needs new /lib/highlighter.lua for syntax highlighting.
    switches:
      -w  = wrap lines longer than screen
      -m  = behave like more

highlighter library:

    reads colors and keywords from /etc/hl.cfg
    functions:
      reload()     = reload config file
      put(x,y,str) = write highlighted string to screen
      line(str)    = write highlighted line to screen using terminal  
      set_color(tag) = set highligter colors:
        number   = whole, floating and hex numbers
        keyword  = lua keywords
        ident    = identifiers
        punct    = punctuation
        comment  = single line comments
        string   = single and double quoted strings
        vstring  = verbatim strings [[]]
        invalid  = invalid characters
        
    
