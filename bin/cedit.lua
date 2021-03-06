local component = require("component")
local event = require("event")
local fs = require("filesystem")
local keyboard = require("keyboard")
local shell = require("shell")
local term = require("term")
local invertedblink = require("invertedblink")
local text = require("text")
local unicode = require("unicode")
local colors = require("colors")
local hl = require("highlighter")

if not term.isAvailable() then
  return
end

local args, options = shell.parse(...)
if #args == 0 then
  io.write("Usage: cedit <filename>")
  return
end

local filename = shell.resolve(args[1])
local readonly = options.r or fs.get(filename) == nil or fs.get(filename).isReadOnly()

if not fs.exists(filename) then
  if fs.isDirectory(filename) then
    io.stderr:write("file is a directory")
    return
  elseif readonly then
    io.stderr:write("file system is read only")
    return
  end
end

local function loadConfig()
  -- Try to load user settings.
  local env = {}
  local config = loadfile("/etc/cedit.cfg", nil, env)
  if config then
    pcall(config)
  end
  -- Fill in defaults.
  env.keybinds = env.keybinds or {
    left = {{"left"}},
    right = {{"right"}},
    up = {{"up"}},
    down = {{"down"}},
    home = {{"home"}},
    eol = {{"end"}},
    pageUp = {{"pageUp"}},
    pageDown = {{"pageDown"}},

    backspace = {{"back"}},
    delete = {{"delete"}},
    deleteLine = {{"control", "delete"}, {"shift", "delete"}},
    newline = {{"enter"}},
    
    save = {{"control", "s"}},
    close = {{"control", "q"}, {"control", "w"}},
    find = {{"control", "f"}},
    findnext = {{"control", "n"}, {"f3"}},
    
    nextword = {{"control", "right"}},
    prevword = {{"control", "left"}},
    gotoline = {{"control", "g"}},
    
    firstline = {{"control", "home"}},
    lastline = {{"control", "end"}},

    scrollup = {{"control", "up"}},
    scrolldown = {{"control", "down"}},
    
    dupeline = {{"control", "d"}}
  }
  env.colors = env.colors or {
    find   = { rgb = { fg = 0x000000, bg = 0xFFFF33 }, pal = { fg = "black",     bg = "yellow" } },
    status = { rgb = { fg = 0xFFFFFF, bg = 0x7F7F7F }, pal = { fg = "white",     bg = "gray" } }
  }
  env.scroll = env.scroll or {
    caret_inplace = true,
    num_lines = 5
  }
  env.ask_save_on_exit = env.ask_save_on_exit or true
  -- convert color names to palette indices
  for k, v in pairs(env.colors) do
    local fg = env.colors[k].pal.fg
    local bg = env.colors[k].pal.bg
    if type(fg) == "string" then
      env.colors[k].pal.fg = colors[fg]
    else
      env.colors[k].pal.fg = fg
    end
    if type(bg) == "string" then
      env.colors[k].pal.bg = colors[bg]
    else
      env.colors[k].pal.bg = bg
    end
  end
  -- Generate config file if it didn't exist.
  if not config then
    local root = fs.get("/")
    if root and not root.isReadOnly() then
      fs.makeDirectory("/etc")
      local f = io.open("/etc/cedit.cfg", "w")
      if f then
        local serialization = require("serialization")
        for k, v in pairs(env) do
          f:write(k.."="..tostring(serialization.serialize(v, math.huge)).."\n")
        end
        f:close()
      end
    end
  end
  return env
end

component.gpu.setForeground(0xFFFFFF)
component.gpu.setBackground(0x000000)
term.clear()
invertedblink.setCursorBlinkInvert(true)
invertedblink.setCursorBlink(true)


local running = true
local buffer = {}
local scrollX, scrollY = 0, 0
local config = loadConfig()
local changed = false

local getKeyBindHandler -- forward declaration for refind()

local function helpStatusText()
  local function prettifyKeybind(label, command)
    local keybind = type(config.keybinds) == "table" and config.keybinds[command]
    if type(keybind) ~= "table" or type(keybind[1]) ~= "table" then return "" end
    local alt, control, shift, key
    for _, value in ipairs(keybind[1]) do
      if value == "alt" then alt = true
      elseif value == "control" then control = true
      elseif value == "shift" then shift = true
      else key = value end
    end
    if not key then return "" end
    return label .. ": [" ..
           (control and "Ctrl+" or "") ..
           (alt and "Alt+" or "") ..
           (shift and "Shift+" or "") ..
           unicode.upper(key) ..
           "] "
  end
  return prettifyKeybind("Save", "save") ..
         prettifyKeybind("Close", "close") ..
         prettifyKeybind("Find", "find") .. 
         prettifyKeybind("Goto", "gotoline")
end

-------------------------------------------------------------------------------
local _oldfg, _oldfgp
local _oldbg, _oldbgp

local function set_hl_color(tag)
  if tag == "status" or tag == "find" then
    local d = component.gpu.getDepth()
    if d == 1 then
      component.gpu.setForeground(0)
      component.gpu.setBackground(1)
    elseif d == 4 then
      component.gpu.setForeground( config.colors[tag].pal.fg, true)
      component.gpu.setBackground( config.colors[tag].pal.bg, true)
    elseif d == 8 then
      component.gpu.setForeground( config.colors[tag].rgb.fg)
      component.gpu.setBackground( config.colors[tag].rgb.bg)
    end
  else
    hl.set_color(tag)
  end
end

local function set_status_color()
  local d = component.gpu.getDepth()
  _oldfg, _oldfgp = component.gpu.getForeground()
  _oldbg, _oldbgp = component.gpu.getBackground()
  set_hl_color("status")
end

local function unset_status_color()
  component.gpu.setForeground(_oldfg, _oldfgp)
  component.gpu.setBackground(_oldbg, _oldbgp)
end

local function setStatus(value)
  local w, h = component.gpu.getResolution()
  set_status_color()
  component.gpu.set(1, h, text.padRight(unicode.sub(value, 1, w - 10), w - 10))
  unset_status_color()
end

local function getSize()
  local w, h = component.gpu.getResolution()
  return w, h - 1
end

local function getCursor()
  local cx, cy = term.getCursor()
  return cx + scrollX, cy + scrollY
end

local function line()
  local cbx, cby = getCursor()
  return buffer[cby]
end

local function setCursor(nbx, nby)
  local w, h = getSize()
  nby = math.max(1, math.min(#buffer, nby))

  local ncy = nby - scrollY
  if ncy > h then
    invertedblink.setCursorBlink(false)
    local sy = nby - h
    local dy = math.abs(scrollY - sy)
    scrollY = sy    
    local b = nby - (dy - 1)
    if nby - b < h then
      component.gpu.copy(1, 1 + dy, w, h - dy, 0, -dy)
    else
      b = nby - h
    end
    for by = b, nby do      
      local str = text.padRight(unicode.sub(buffer[by], 1 + scrollX), w)
      hl.put(1, by - scrollY, str)
    end
  elseif ncy < 1 then
    invertedblink.setCursorBlink(false)
    local sy = nby - 1
    local dy = math.abs(scrollY - sy)
    scrollY = sy
    local e = nby + (dy - 1)
    if e - nby < h then
      component.gpu.copy(1, 1, w, h - dy, 0, dy)
    else
      e = nby + h
    end
    for by = nby, e do
      local str = text.padRight(unicode.sub(buffer[by], 1 + scrollX), w)
      hl.put(1, by - scrollY, str)
    end
  end
  invertedblink.setCursor(term.getCursor(), nby - scrollY)

  nbx = math.max(1, math.min(unicode.len(line()) + 1, nbx))
  local ncx = nbx - scrollX
  if ncx > w then
    invertedblink.setCursorBlink(false)
    local sx = nbx - w
    local dx = math.abs(scrollX - sx)
    scrollX = sx
    component.gpu.copy(1 + dx, 1, w - dx, h, -dx, 0)
    for by = 1 + scrollY, math.min(h + scrollY, #buffer) do
      local str = unicode.sub(buffer[by], nbx - (dx - 1), nbx)
      str = text.padRight(str, dx)
      hl.put(1 + (w - dx), by - scrollY, str)
    end
  elseif ncx < 1 then
    invertedblink.setCursorBlink(false)
    local sx = nbx - 1
    local dx = math.abs(scrollX - sx)
    scrollX = sx
    component.gpu.copy(1, 1, w - dx, h, dx, 0)
    for by = 1 + scrollY, math.min(h + scrollY, #buffer) do
      local str
      if nbx == 1 then
        str = unicode.sub(buffer[by], 1, w)
      else
        str = unicode.sub(buffer[by], nbx, nbx + dx)
      end
      --str = text.padRight(str, dx)
      hl.put(1, by - scrollY, str)
    end
  end
  invertedblink.setCursor(nbx - scrollX, nby - scrollY)
  
  set_status_color()
  component.gpu.set(w - 9, h + 1, text.padLeft(string.format("%d,%d", nby, nbx), 10))
  unset_status_color()
end

local function highlight(bx, by, length, enabled)
  local w, h = getSize()
  local cx, cy = bx - scrollX, by - scrollY
  cx = math.max(1, math.min(w, cx))
  cy = math.max(1, math.min(h, cy))
  length = math.max(1, math.min(w - cx, length))

  if enabled then
    local fg, fgp = component.gpu.getForeground()
    local bg, bgp = component.gpu.getBackground()
    set_hl_color("find")
    local str = unicode.sub(buffer[by], bx, bx + length - 1)
    component.gpu.set(cx, cy, str)
    component.gpu.setForeground(fg, fgp)
    component.gpu.setBackground(bg, bgp)
  else
    local str = text.padRight(unicode.sub(buffer[by], 1 + scrollX), w)
    hl.put(1, cy, str)
  end
end

local function home()
  local cbx, cby = getCursor()
  setCursor(1, cby)
end

local function ende()
  local cbx, cby = getCursor()
  setCursor(unicode.len(line()) + 1, cby)
end

local function left()
  local cbx, cby = getCursor()
  if cbx > 1 then
    setCursor(cbx - 1, cby)
    return true -- for backspace
  elseif cby > 1 then
    setCursor(cbx, cby - 1)
    ende()
    return true -- again, for backspace
  end
end

local function right(n)
  n = n or 1
  local cbx, cby = getCursor()
  local be = unicode.len(line()) + 1
  if cbx < be then
    setCursor(cbx + n, cby)
  elseif cby < #buffer then
    setCursor(1, cby + 1)
  end
end

local function up(n)
  n = n or 1
  local cbx, cby = getCursor()
  if cby > 1 then
    setCursor(cbx, cby - n)
    if getCursor() > unicode.len(line()) then
      ende()
    end
  end
end

local function down(n)
  n = n or 1
  local cbx, cby = getCursor()
  if cby < #buffer then
    setCursor(cbx, cby + n)
    if getCursor() > unicode.len(line()) then
      ende()
    end
  end
end

local function scrollup(n)
  local w, h = getSize()
  local x, y = getCursor()
  local cx, cy = term.getCursor()
  n = n or 1
  if cy == h then
    up(h + (n - 1))
    setCursor( x, y - n)
  else
    up(cy + (n - 1))
    if config.scroll.caret_inplace then
      if y > scrollY + h then
        y = scrollY + h
      end
      setCursor( x, y)
    else
      setCursor( x, y - n)
    end
  end
end

local function scrolldown(n)
  local w, h = getSize()
  local x, y = getCursor()
  local cx, cy = term.getCursor()
  n = n or 1
  if cy == 1 then
    down(h + (n - 1))
    setCursor( x, y + n)
  else
    down((h - cy) + n)
    if config.scroll.caret_inplace then
      if y <= scrollY then
        y = scrollY + 1
      end
      setCursor( x, y)
    else
      setCursor( x, y + n)
    end
  end  
end

local function firstline()
  setCursor( 1, 1)
end

local function lastline()
  setCursor( 1, #buffer)
end

local function nextword()
  local cbx, cby = getCursor()
  local str = buffer[cby]
  if cbx >= string.len(str) then
-- move across lines
    cbx = 1
    repeat
      cby = cby + 1
    until string.len(buffer[cby]) > 0
    setCursor( cbx, cby)
    str = buffer[cby]
  end
  local b, e = true, cbx + 1
  if string.find( str, "^[%l%u%d_]", cbx) then
    b, e = string.find( str, "[%l%u%d_]+", cbx)
    if b then
      e = e + 1
    end
  elseif string.find( str, "^%p", cbx) then
    b, e = string.find( str, "^%p*%s*", cbx + 1)
    if b then
      e = e + 1
    end
  elseif string.find( str, "^%s", cbx) then
    b, e = string.find( str, "^%s+", cbx)
    if b then
      e = e + 1
    end
  end
  if b then
    local bb, ee = string.find( str, "^%s+", e)
    if bb then
      e = ee + 1
    end
    setCursor( e, cby)
  end
end

local function prevword()
  local function skipword( str, start)
    for i = start, 1, -1 do
      if string.find( str, "^%s", i) then
        return i + 1
      elseif string.find( str, "^%p", i) then
        return i
      end
    end
    return 1
  end
  local function skipspace( str, start)
    for i = start, 1, -1 do
      if string.find( str, "^%S", i) then
        return i
      end
    end
    return 1
  end
  local cbx, cby = getCursor()
  local str = buffer[cby]
  local bb, ee = string.find( str, "^%s*")
  if bb and (cbx <= 1 or ee == cbx - 1) then
-- move across lines
    repeat
      cby = cby - 1
    until string.len(buffer[cby]) > 0
    cbx = string.len(buffer[cby])
    setCursor( cbx, cby)
  end
  str = buffer[cby]
  if cbx > string.len(str) then
    cbx = cbx - 1
  end
  if string.find( str, "^%s", cbx) then
    cbx = skipspace( str, cbx)
    if string.find( str, "^[%u%l%d_]", cbx) then
      cbx = skipword( str, cbx)
    end
    setCursor( cbx, cby)
  elseif string.find( str, "^%p", cbx) then
    for i = cbx - 1, 1, -1 do
      if string.find( str, "^%s", i) then
        cbx = skipspace( str, i)
        cbx = skipword( str, cbx)
        break
      elseif string.find( str, "^[%l%u%d_]", i) then
        cbx = skipword( str, i)
        break
      end
    end
    setCursor( cbx, cby)
  elseif string.find( str, "^[%l%u%d_]", cbx) then
    cbx = skipspace( str, cbx - 1)
    cbx = skipword( str, cbx)
    setCursor( cbx, cby)
  end
end

local function delete(fullRow)
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = getSize()
  local function deleteRow(row)
    local content = table.remove(buffer, row)
    local rcy = cy + (row - cby)
    if rcy <= h then
      component.gpu.copy(1, rcy + 1, w, h - rcy, 0, -1)
      hl.put(1, h, text.padRight(buffer[row + (h - rcy)], w))
    end
    return content
  end
  if fullRow then
    invertedblink.setCursorBlink(false)
    if #buffer > 1 then
      deleteRow(cby)
    else
      buffer[cby] = ""
      component.gpu.fill(1, cy, w, 1, " ")
    end
    setCursor(1, cby)
  elseif cbx <= unicode.len(line()) then
    invertedblink.setCursorBlink(false)
    buffer[cby] = unicode.sub(line(), 1, cbx - 1) ..
                  unicode.sub(line(), cbx + 1)
    component.gpu.copy(cx + 1, cy, w - cx, 1, -1, 0)
    local br = cbx + (w - cx)
    local char = unicode.sub(line(), br, br)
    if not char or unicode.len(char) == 0 then
      char = " "
    end
    local str = text.padRight(unicode.sub(buffer[cby], 1 + scrollX), w)
    hl.put(1, cy, str)
  elseif cby < #buffer then
    invertedblink.setCursorBlink(false)
    local append = deleteRow(cby + 1)
    buffer[cby] = buffer[cby] .. append
    local str = text.padRight(unicode.sub(buffer[cby], 1 + scrollX), w)
    hl.put(1, cy, str)
  else
    return
  end
  setStatus(helpStatusText())
  changed = true
end

local function insert(value)
  if not value or unicode.len(value) < 1 then
    return
  end
  invertedblink.setCursorBlink(false)
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = getSize()
  buffer[cby] = unicode.sub(line(), 1, cbx - 1) ..
                value ..
                unicode.sub(line(), cbx)
  local len = unicode.len(value)
  local n = w - (cx - 1) - len
  if n > 0 then
    component.gpu.copy(cx, cy, n, 1, len, 0)
  end
  --component.gpu.set(cx, cy, value)
  local str = text.padRight(unicode.sub(buffer[cby], 1 + scrollX), w)
  hl.put(1, cy, str)
  right(len)
  setStatus(helpStatusText())
  changed = true
end

local function enter()
  invertedblink.setCursorBlink(false)
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local w, h = getSize()
  table.insert(buffer, cby + 1, unicode.sub(buffer[cby], cbx))
  buffer[cby] = unicode.sub(buffer[cby], 1, cbx - 1)
  component.gpu.fill(cx, cy, w - (cx - 1), 1, " ")
  if cy < h then
    if cy < h - 1 then
      component.gpu.copy(1, cy + 1, w, h - (cy + 1), 0, 1)
    end
    --component.gpu.set(1, cy + 1, text.padRight(buffer[cby + 1], w))
    local str = text.padRight(unicode.sub(buffer[cby + 1], 1 + scrollX), w)
    hl.put(1, cy + 1, str)
  end
  setCursor(1, cby + 1)
  setStatus(helpStatusText())
  changed = true
end

local function dupeline()
  local s = line()
  ende()
  enter()
  insert(s)
  home()
end

function saveonexit()
  local w, h = getSize()
  local cx, cy = getCursor()
  while running do
    local str = "File has changed, save before exit?"
    local opt = " [Y/N]"
    invertedblink.setCursor( string.len(str) + string.len(opt) + 3, h + 1)
    setStatus(str)    
    local fg = component.gpu.setForeground( colors.red, true)
    local bg = component.gpu.setBackground( config.colors.status.pal.bg, true)
    component.gpu.set( string.len(str) + 1, h + 1, opt)
    component.gpu.setForeground( config.colors.status.pal.fg, true)
    component.gpu.set( string.len(str) + 1 + string.len(opt), h + 1, ":")
    component.gpu.setForeground(fg)
    component.gpu.setBackground(bg)
    
    local _, _, char, code = event.pull("key_down")
    local handler, name = getKeyBindHandler(code)
    if name == "newline" then
      break
    elseif name == "close" then
      return "nosave"
    elseif not keyboard.isControl(char) then
      char = unicode.char(char)
      if char == "y" or char == "Y" then
        return "save"
      elseif char == "n" or char == "N" then
        return "nosave"
      end
    end
  end
  setStatus(helpStatusText())
  setCursor( cx, cy)
  return "cancel"
end

local gotoText = ""

function gotoline()
  local w, h = getSize()
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local ibx, iby = cbx, cby
  while running do
    invertedblink.setCursor(7 + unicode.len(gotoText), h + 1)
    local ok = false
    if unicode.len(gotoText) > 0 then
      local num = tonumber(gotoText)
      if num and (num < 1 or num > #buffer) then
        ok = true
      end
    end
    setStatus("Goto: " .. gotoText)    
    if ok and unicode.len(gotoText) > 0 then
      local fg = component.gpu.setForeground( colors.red, true)
      component.gpu.set( 7 + unicode.len(gotoText) + 1, h + 1,  " -- out of bounds!")
      component.gpu.setForeground(fg)
    end

    local _, _, char, code = event.pull("key_down")
    local handler, name = getKeyBindHandler(code)
    if name == "newline" then
      if unicode.len(gotoText) > 0 then
        local num = tonumber(gotoText)
        if num and num >= 1 and num <= #buffer then
          setCursor( 1, num)
        end
      else
        setCursor( cbx, cby)
      end
      break
    elseif name == "close" then
      handler()
    elseif name == "backspace" then
      gotoText = unicode.sub(gotoText, 1, -2)
    elseif not keyboard.isControl(char) then
      char = unicode.char(char)
      if string.find( char, "^%d") then
        gotoText = gotoText .. char
      end
    end
  end
  setStatus(helpStatusText())
end

local findText = ""

local function find()
  local w, h = getSize()
  local cx, cy = term.getCursor()
  local cbx, cby = getCursor()
  local ibx, iby = cbx, cby
  while running do
    local found = false
    if unicode.len(findText) > 0 then
      local sx, sy
      for syo = 1, #buffer do -- iterate lines with wraparound
        sy = (iby + syo - 1 + #buffer - 1) % #buffer + 1
        sx = string.find(buffer[sy], findText, syo == 1 and ibx or 1, true)
        if sx and (sx >= ibx or syo > 1) then
          break
        end
      end
      if not sx then -- special case for single matches
        sy = iby
        sx = string.find(buffer[sy], findText, 1, true)
      end
      if sx then
        cbx, cby = sx, sy
        setCursor(cbx, cby)
        highlight(cbx, cby, unicode.len(findText), true)
        found = true
      end
    end
    invertedblink.setCursor(7 + unicode.len(findText), h + 1)
    setStatus("Find: " .. findText)
    if not found and unicode.len(findText) > 0 then
      local fg = component.gpu.setForeground( colors.red, true)
      component.gpu.set( 7 + unicode.len(findText) + 1, h + 1,  " -- no match found!")
      component.gpu.setForeground(fg)
    end

    local _, _, char, code = event.pull("key_down")
    local handler, name = getKeyBindHandler(code)
    highlight(cbx, cby, unicode.len(findText), false)
    if name == "newline" then
      break
    elseif name == "close" then
      handler()
    elseif name == "backspace" then
      findText = unicode.sub(findText, 1, -2)
    elseif name == "find" or name == "findnext" then
      ibx = cbx + 1
      iby = cby
    elseif not keyboard.isControl(char) then
      findText = findText .. unicode.char(char)
    end
  end
  setCursor(cbx, cby)
  setStatus(helpStatusText())
end

-------------------------------------------------------------------------------

local keyBindHandlers = {
  left = left,
  right = right,
  up = up,
  down = down,
  home = home,
  eol = ende,
  pageUp = function()
    local w, h = getSize()
    up(h - 1)
  end,
  pageDown = function()
    local w, h = getSize()
    down(h - 1)
  end,

  backspace = function()
    if not readonly and left() then
      delete()
    end
  end,
  delete = function()
    if not readonly then
      delete()
    end
  end,
  deleteLine = function()
    if not readonly then
      delete(true)
    end
  end,
  newline = function()
    if not readonly then
      enter()
    end
  end,
  
  nextword = nextword,
  prevword = prevword,

  save = function()
    if readonly then return end
    local new = not fs.exists(filename)
    local backup
    if not new then
      backup = filename .. "~"
      for i = 1, math.huge do
        if not fs.exists(backup) then
          break
        end
        backup = filename .. "~" .. i
      end
      fs.copy(filename, backup)
    end
    local f, reason = io.open(filename, "w")
    if f then
      local chars, firstLine = 0, true
      for _, line in ipairs(buffer) do
        if not firstLine then
          line = "\n" .. line
        end
        firstLine = false
        f:write(line)
        chars = chars + unicode.len(line)
      end
      f:close()
      local format
      if new then
        format = [["%s" [New] %dL,%dC written]]
      else
        format = [["%s" %dL,%dC written]]
      end
      setStatus(string.format(format, fs.name(filename), #buffer, chars))
      changed = false
    else
      setStatus(reason)
    end
    if not new then
      fs.remove(backup)
    end
  end,
  find = function()
    findText = ""
    find()
  end,
  findnext = find,
  gotoline = function()
    gotoText = ""
    gotoline()
  end,
  firstline = firstline,
  lastline = lastline,
  scrollup = scrollup,
  scrolldown = scrolldown,
  dupeline = dupeline
}

function keyBindHandlers.close()
    if changed and config.ask_save_on_exit then
      local x = saveonexit()
      if x == "save" then
        keyBindHandlers.save()
        running = false
      elseif x == "nosave" then
        running = false
      elseif x == "cancel" then
        -- dont do anything
      end
    else
      running = false
    end
  end

getKeyBindHandler = function(code)
  if type(config.keybinds) ~= "table" then return end
  -- Look for matches, prefer more 'precise' keybinds, e.g. prefer
  -- ctrl+del over del.
  local result, resultName, resultWeight = nil, nil, 0
  for command, keybinds in pairs(config.keybinds) do
    if type(keybinds) == "table" and keyBindHandlers[command] then
      for _, keybind in ipairs(keybinds) do
        if type(keybind) == "table" then
          local alt, control, shift, key
          for _, value in ipairs(keybind) do
            if value == "alt" then alt = true
            elseif value == "control" then control = true
            elseif value == "shift" then shift = true
            else key = value end
          end
          if (not alt or keyboard.isAltDown()) and
             (not control or keyboard.isControlDown()) and
             (not shift or keyboard.isShiftDown()) and
             code == keyboard.keys[key] and
             #keybind > resultWeight
          then
            resultWeight = #keybind
            resultName = command
            result = keyBindHandlers[command]
          end
        end
      end
    end
  end
  return result, resultName
end

-------------------------------------------------------------------------------

local function onKeyDown(char, code)
  local handler = getKeyBindHandler(code)
  if handler then
    handler()
  elseif readonly and code == keyboard.keys.q then
    running = false
  elseif not readonly then
    if not keyboard.isControl(char) then
      insert(unicode.char(char))
    elseif unicode.char(char) == "\t" then
      insert("  ")
    end
  end
end

local function onClipboard(value)
  value = value:gsub("\r\n", "\n")
  local cbx, cby = getCursor()
  local start = 1
  local l = value:find("\n", 1, true)
  if l then
    repeat
      local line = string.sub(value, start, l - 1)
      line = text.detab(line, 2)
      insert(line)
      enter()
      start = l + 1
      l = value:find("\n", start, true)
    until not l
  end
  insert(string.sub(value, start))
end

local function onClick(x, y)
  local w, h = getSize()
  if y <= h then
    setCursor(x + scrollX, y + scrollY)
  end
end

local function onScroll(direction)
  local cbx, cby = getCursor()
  if direction < 0 then
    scrolldown( math.abs(direction) * config.scroll.num_lines)
  else
    scrollup( direction * config.scroll.num_lines)
  end
end

-------------------------------------------------------------------------------
hl.reload()
do
  local f = io.open(filename)
  if f then
    local w, h = getSize()
    local chars = 0
    for line in f:lines() do
      if line:sub(-1) == "\r" then
        line = line:sub(1, -2)
      end
      line = string.gsub( line, "\t", "  ")
      table.insert(buffer, line)
      chars = chars + unicode.len(line)
      if #buffer <= h then
        hl.put(1, #buffer, line)
      end
    end
    f:close()
    if #buffer == 0 then
      table.insert(buffer, "")
    end
    local format
    if readonly then
      format = [["%s" [readonly] %dL,%dC]]
    else
      format = [["%s" %dL,%dC]]
    end
    setStatus(string.format(format, fs.name(filename), #buffer, chars))
  else
    table.insert(buffer, "")
    setStatus(string.format([["%s" [New File] ]], fs.name(filename)))
  end
  setCursor(1, 1)
end


while running do
  local event, address, arg1, arg2, arg3 = event.pull()
  if type(address) == "string" and component.isPrimary(address) then
    local blink = true
    if event == "key_down" then
      onKeyDown(arg1, arg2)
    elseif event == "clipboard" and not readonly then
      onClipboard(arg1)
    elseif event == "touch" or event == "drag" then
      onClick(arg1, arg2)
    elseif event == "scroll" then
      onScroll(arg3)
    else
      blink = false
    end
    if blink then
      invertedblink.setCursorBlink(true)
      invertedblink.setCursorBlink(true) -- force toggle to caret
    end
  end
end

invertedblink.setCursorBlinkInvert(false)
invertedblink.setCursorBlink(false)
local d = component.gpu.getDepth()
if d == 1 then
  component.gpu.setForeground(0xFFFFFF)
  component.gpu.setBackground(0x000000)
elseif d == 4 then
  component.gpu.setForeground(colors.white, true)
  component.gpu.setBackground(colors.black, true)
elseif d == 8 then
  component.gpu.setForeground(0xFFFFFF)
  component.gpu.setBackground(0x000000)
end
term.clear()