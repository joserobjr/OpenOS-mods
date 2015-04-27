local component = require("component")
local event = require("event")
local keyboard = require("keyboard")
local shell = require("shell")
local term = require("term")
local unicode = require("unicode")
local hl = require("highlighter")

if not term.isAvailable() then
  return false
end

local function waitkey()
  while true do
    local event, address, char, code = event.pull("key_down")
    if component.isPrimary(address) then
      if code == keyboard.keys.q then
        return "exit"
      elseif code == keyboard.keys.space or code == keyboard.keys.pageDown then
        return "page"
      elseif code == keyboard.keys.enter or code == keyboard.keys.down then
        return "line"
      end
    end
  end
end

----------------------------------------------------------------------------
hl.reload()
local args
args, options = shell.parse(...)
term.setCursorBlink(false)
if #args == 0 then
  local w, h = component.gpu.getResolution()
  local num = 0
  repeat
    local read = io.read("*L")
    if read then
      if string.find( read, "\n$") then
        read = string.sub( read, 1, -2)
      end
      if string.len(read) > 0 then
        num = num + hl.line( read, options.w)
      else
        num = num + 1
        term.write("\n")
      end      
      if options.m and num >= h - 1 then
        term.write(":")
        term.setCursorBlink(true)      
        local k = waitkey()
        term.clearLine()
        term.setCursorBlink(false)
        if k == "exit" then
          break
        elseif k == "page" then
          num = 0
        elseif k == "line" then
          num = num - 1
        end
      end
    end
  until not read
else
  for i = 1, #args do
    local file, reason = io.open(shell.resolve(args[i]))
    if not file then
      io.stderr:write(reason)
      return
    end
    local w, h = component.gpu.getResolution()
    local num = 0    
    repeat
      local line = file:read("*L")
      if line then
        if string.find( line, "\n$") then
          line = string.sub( line, 1, -2)
        end
        if string.len(line) > 0 then
          num = num + hl.line( line, options.w)
        else
          num = num + 1
          term.write("\n")
        end
      end
      num = num + 1
      if options.m and num >= h - 1 then
        term.write(":")
        term.setCursorBlink(true)
        local k = waitkey()
        term.clearLine()
        term.setCursorBlink(false)
        if k == "exit" then
          break
        elseif k == "page" then
          num = 0
        elseif k == "line" then
          num = num - 1
        end
      end
    until not line
    file:close()
  end
end
term.setCursorBlink(true)