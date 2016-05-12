# OpenOS-mods
An editor software for [OpenComputers](https://github.com/MightyPirates/OpenComputers) that supports syntax highlighting

![Example](http://i.imgur.com/dAf7Yge.png)

This project contains:

    Syntax highlighter library.
    Syntax highlighting version of /bin/edit.lua (cedit).
    Syntax highlighting version of /bin/more.lua (hl).
    Inverted blinking cursor library (for cedit).

Installation:

    The easiest way (just replaces 12 chars):
        edit /usr/bin/oppm.lua
        Scroll down until you find "https://raw.githubusercontent.com/OpenPrograms/openprograms.github.io/master/repos.cfg"
        Replace that to "https://raw.githubusercontent.com/joserobjr/openprograms.github.io/master/repos.cfg"
        Ctrl+S, Ctrl+W
        oppm install cedit
        You can safely revert the URL on oppm.lua to OpenPrograms now
    
    The hard way (write to the config, copy, paste and must respect the lua syntax):
        Open programs.cfg on this repository
        Copy everything
        edit /etc/oppm.cfg
        Add this to repos:
            repos={
                ["joserobjr/OpenOS-mods"] = /*** paste here with INSERT key ***/
            }
        Ctrl+S, Ctrl+W
        oppm install cedit
        
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
        
    
