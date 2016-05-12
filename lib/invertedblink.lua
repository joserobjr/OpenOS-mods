local component = require("component")
local event = require("event")
local process = require("process")
local term = require("term")

local invert_cursor_blink = false
local invertedblink = {}

invertedblink.internal = {}

function invertedblink.internal.window()
  return process.info().data.window
end

local W = invertedblink.internal.window

local function toggleBlink()
  local w = W()
  if term.isAvailable() then
    cursorBlink.state = not cursorBlink.state
    if invert_cursor_blink then
      local d = component.gpu.getDepth()
      if cursorBlink.state then
        local alt, fg, bg, fgp, bgp = component.gpu.get(w.x, w.y)
        if fg == bg then
          fg = 0xFFFFFF
          bg = 0x000000
        end
        if fgp == bgp then
          fgp = 0
          bgp = 15
        end        
        cursorBlink.alt = alt or cursorBlink.alt
        cursorBlink.altfg = fg or fgp
        cursorBlink.altbg = bg or bgp
        cursorBlink.altfgp = fgp or fg
        cursorBlink.altbgp = bgp or bg
        if d == 1 then
          component.gpu.setForeground(cursorBlink.altbg)
          component.gpu.setBackground(cursorBlink.altfg)
        elseif d == 4 then
          component.gpu.setForeground(cursorBlink.altbgp, true)
          component.gpu.setBackground(cursorBlink.altfgp, true)
        elseif d == 8 then
          component.gpu.setForeground(cursorBlink.altbg)
          component.gpu.setBackground(cursorBlink.altfg)
        end
        component.gpu.set(w.x, w.y, cursorBlink.alt)
      else
        if d == 1 then
          component.gpu.setForeground(cursorBlink.altfg)
          component.gpu.setBackground(cursorBlink.altbg)
        elseif d == 4 then
          component.gpu.setForeground(cursorBlink.altfgp, true)
          component.gpu.setBackground(cursorBlink.altbgp, true)
        elseif d == 8 then
          component.gpu.setForeground(cursorBlink.altfg)
          component.gpu.setBackground(cursorBlink.altbg)
        end
        component.gpu.set(w.x, w.y, cursorBlink.alt)
      end
    else
      if cursorBlink.state then
        cursorBlink.alt = component.gpu.get(w.x, w.y) or cursorBlink.alt
        component.gpu.set(w.x, w.y, string.rep(unicode.char(0x2588), unicode.charWidth(cursorBlink.alt))) -- solid block
      else
        component.gpu.set(w.x, w.y, cursorBlink.alt)
      end
    end
  end
end

function invertedblink.setCursorBlinkInvert(enabled)
  invert_cursor_blink = enabled
end

function invertedblink.setCursorBlink(enabled)
  if enabled then
    if invert_cursor_blink then
		if not cursorBlink then
		  cursorBlink = {}
		  cursorBlink.id = event.timer(0.5, toggleBlink, math.huge)
		  cursorBlink.state = false
		  cursorBlink.alt = " "
		  cursorBlink.altfg = 0xFFFFFF
		  cursorBlink.altbg = 0x000000
		  cursorBlink.altfgp = 0
		  cursorBlink.altbgp = 15
		elseif not cursorBlink.state then
		  toggleBlink()
		end
	end
  elseif cursorBlink then
    event.cancel(cursorBlink.id)
    if cursorBlink.state then
      toggleBlink()
    end
    cursorBlink = nil
  end
  W().blink=enabled
end

function invertedblink.setCursor(x,y)
  local w = W()
  if cursorBlink and cursorBlink.state then
    toggleBlink()
  end
  w.x,w.y=x,y
end

return invertedblink