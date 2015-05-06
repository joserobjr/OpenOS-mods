# OpenOS-mods
Modifications and additions to [OpenOS](https://github.com/MightyPirates/OpenComputers/tree/master-MC1.8/src/main/resources/assets/opencomputers/loot/OpenOS) that comes with a Minecraft mod called  [OpenComputers](https://github.com/MightyPirates/OpenComputers/tree/master-MC1.8).

These files are from *OpenComputers-MC1.8-1.5.8.19*.

Noteable changes:

    Persistence of aliases.
    Persistence of environment variables.
    File size switches for ls command (-s -h -si).
    Reset color switch to clear command (-c).
    Syntax highlighter library.
    Syntax highlighting version of /bin/edit.lua (cedit).
    Syntax highlighting version of /bin/more.lua (hl).
    Inverted blinking cursor to term (for cedit).

Installation:

    Copy files into an allready existing copy of OpenOS, usualy located in
      "%APPDATA%\Roaming\.minecraft\saves\YOUT_WORLD_NAME\opencomputers\YOUR_MAIN_HD"
    where YOUR_WORLD_NAME is the name of your world and YOUR_MAIN_HD is the full address of your main hd.

cedit - syntax highlighting editor:

    reads keybindings and ui colors from /etc/cedit.cfg
    needs updated /lib/term.lua for inverted blinking cursor.
    needs new /lib/highlighter.lua for syntax highlighting.
    new keybindings:
      ctrl + g    = goto line
      ctrl + d    = duplicate line
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
        
    
