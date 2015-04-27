local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local term = require("term")
local unicode = require("unicode")
local colors = require("colors")

local config = {}
local hl = {}

local function loadConfig()
  -- Try to load user settings.
  local env = {}
  local config = loadfile("/etc/hl.cfg", nil, env)
  if config then
    pcall(config)
  end
  -- Fill in defaults.
  if env.colors then
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
  else
    env.colors = {
      number     = { rgb = { fg = 0x9933CC, bg = 0x000000 }, pal = { fg = colors.purple,    bg = colors.black } },
      keyword    = { rgb = { fg = 0x6899FF, bg = 0x000000 }, pal = { fg = colors.lightblue, bg = colors.black } },
      ident      = { rgb = { fg = 0xFFFFFF, bg = 0x000000 }, pal = { fg = colors.white,     bg = colors.black } },
      punct      = { rgb = { fg = 0xCCCCCC, bg = 0x000000 }, pal = { fg = colors.silver,    bg = colors.black } },
      comment    = { rgb = { fg = 0x336600, bg = 0x000000 }, pal = { fg = colors.green,     bg = colors.black } },
      string     = { rgb = { fg = 0x33CC33, bg = 0x000000 }, pal = { fg = colors.lime,      bg = colors.black } },
      vstring    = { rgb = { fg = 0x33CC33, bg = 0x7F7F7F }, pal = { fg = colors.lime,      bg = colors.gray } },
      invalid    = { rgb = { fg = 0xFFFFFF, bg = 0xFF0000 }, pal = { fg = colors.white,     bg = colors.red } },
    }
  end
  env.keywords = env.keywords or {
    ["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
    ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
    ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
    ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
    ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
    ["until"]=true, ["while"]=true
  }
  -- Generate config file if it didn't exist.
  if not config then
    local root = fs.get("/")
    if root and not root.isReadOnly() and not fs.exists("/etc/hl.cfg") then
      fs.makeDirectory("/etc")
      local f = io.open("/etc/hl.cfg", "w")
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

function hl.reload()
  config = {}
  config = loadConfig()
end

function hl.set_color(tag)
  local d = component.gpu.getDepth()
  if d == 1 then
    component.gpu.setForeground(1)
    component.gpu.setBackground(0)
  elseif d == 4 then
    component.gpu.setForeground( config.colors[tag].pal.fg, true)
    component.gpu.setBackground( config.colors[tag].pal.bg, true)
  elseif d == 8 then
    component.gpu.setForeground( config.colors[tag].rgb.fg)
    component.gpu.setBackground( config.colors[tag].rgb.bg)
  end
end

function hl.put( x, y, str)
  local gpu = component.gpu
  local d = gpu.getDepth()
  if d == 1 then
    hl.set_color("ident")
    gpu.set( x, y, str)
    return
  end
  local fg, fgp = gpu.getForeground()
  local bg, bgp = gpu.getBackground()
  local i, len = 1, string.len(str)
  while i <= len do
    if string.find( str, "^%-%-", i) then
-- comments
      hl.set_color("comment")
      gpu.set( x + i - 1, y,  string.sub( str, i))
      break
    end
    if string.find( str, "^[%u%l_]", i) then
-- keywords and identifiers
      local start = i
      i = i + 1
      local b, e = string.find( str, "^[%u%l%d_]+", i)
      if b then
        i = e + 1
      end
      local k = string.sub( str, start, i - 1)
      if config.keywords[k] then
        hl.set_color("keyword")
      else
        hl.set_color("ident")
      end
      gpu.set( x + start - 1, y, k)
    elseif string.find( str, "^%d", i) then
-- numbers
      local start = i
      i = i + 1
      local b, e = string.find( str, "^x%x+", i)
      if not b then
        b, e = string.find( str, "^%d*%.?%d*", i)
      end
      if b then
        i = e + 1
      end
      local k = string.sub( str, start, i - 1)
      hl.set_color("number")
      gpu.set( x + start - 1, y, k)
    elseif string.find( str, "^[\"']", i) then
-- strings
      local q = "^" .. string.sub( str, i, i)
      local start = i
      i = i + 1
      while i <= str:len() do
        if string.find( str, q, i) then
          break
        elseif string.find( str, "^\\", i) then
          i = i + 1
        end
        i = i + 1
      end 
      i = i + 1
      local k = string.sub( str, start, i - 1)
      hl.set_color("string")
      gpu.set( x + start - 1, y, k)
    elseif string.find( str, "^%[%[", i) then
-- verbatim strings
      local start = i
      i = i + 2
      local b, e = string.find( str, "%]%]", i)
      if e then
        i = e + 1
      end
      local k = string.sub( str, start, i)
      hl.set_color("vstring")
      gpu.set( x + start - 1, y, k)
    elseif string.find( str, "^[%p%s]", i) then
-- whitespace & punctuation
      local b, e = string.find( str, "^[%p%s]+", i)
      i = e + 1
      -- dont allow string and comment starters at end
      for ii = b, e do
        if string.find( str, "^['\"]", ii) or string.find( str, "^%[%[", ii) or string.find( str, "^%-%-", ii) then
          i = ii
          e = ii - 1
          break
        end
      end
      hl.set_color("punct")
      gpu.set( x + b - 1, y, string.sub( str, b, e))
    else
-- invalid characters
      hl.set_color("invalid")
      gpu.set( x + i - 1, y, string.sub( str, i, i))
      i = i + 1
    end    
  end
  gpu.setForeground(fg, fgp)
  gpu.setBackground(bg, bgp)
end

-- returns number of lines outputted
function hl.line( str, wrap)
  local w, h = component.gpu.getResolution()
  local cx, cy = term.getCursor()
  local dx = w - unicode.len(str)
  if dx >= 0 and dx <= w then
    hl.put( cx, cy, str)
    term.setCursor( cx + unicode.len(str), cy)
    term.write("\n")
    return 1
  elseif wrap and wrap == true then
    local count = 0
    while unicode.len(str) > 0 do
      -- +-8=length of largest keyword, for highlighting tokens split on screen border
      local ww = math.min( w + 8, unicode.len(str))
      local s1 = unicode.sub( str, 1, ww)
      if unicode.len(str) > w - 8 then
        str = unicode.sub( str, w - 8)
      else
        str = ""
      end
      hl.put( cx, cy, s1)
      if cx < 1 then
        term.setCursor( 1 + unicode.len(s1), cy)
      else
        term.setCursor( cx + unicode.len(s1), cy)
      end
      term.write("\n")
      cx, cy = term.getCursor()
      cx = -8
      count = count + 1
    end
    return count
  else
    local ww = math.min( w + 8, unicode.len(str))
    hl.put( cx, cy, unicode.sub( str, 1, ww))
    term.setCursor( cx + ww, cy)
    term.write("\n")
    return 1
  end
end

config = loadConfig()
return hl