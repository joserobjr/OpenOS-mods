local component = require("component")
local fs = require("filesystem")
local shell = require("shell")
local text = require('text')
local unicode = require("unicode")

local _, options = shell.parse(os.getenv("LS_OPTIONS"))
local dirs, argopts = shell.parse(...)
if #dirs == 0 then
  table.insert(dirs, ".")
end
for k, v in pairs(argopts) do
  options[k] = v
end

local function formatSize(size) --from df.lua
  if not options.h then
    return tostring(size)
  end
  local sizes = {"", "K", "M", "G"}
  local unit = 1
  local power = options.si and 1000 or 1024
  while size > power and unit < #sizes do
    unit = unit + 1
    size = size / power
  end
  return math.floor(size * 10) / 10 .. sizes[unit]
end

io.output():setvbuf("line")
for i = 1, #dirs do
  local path = shell.resolve(dirs[i])
  if #dirs > 1 then
    if i > 1 then
      io.write("\n")
    end
    io.write(path, ":\n")
  end
  local list, reason = fs.list(path)
  if not list then
    io.write(reason .. "\n")
  else
    local function setColor(c)
      if component.isAvailable("gpu") and component.gpu.getForeground() ~= c then
        io.stdout:flush()
        component.gpu.setForeground(c)
      end
    end
    local lsd = {}
    local lsf = {}
    local m = 1
    for f in list do
      m = math.max(m, f:len() + 2)
      if f:sub(-1) == "/" then
        if options.p then
          table.insert(lsd, f)
        else
          table.insert(lsd, f:sub(1, -2))
        end
      else
        table.insert(lsf, f)
      end
    end
    table.sort(lsd)
    table.sort(lsf)
    
    local lsfsz = {}
    local tsz = 0
    local msz = 3
    if options.s then
      for _, f in ipairs(lsf) do
        local sz = fs.size(fs.concat(path, f))
        tsz = tsz + sz
        local str = formatSize(sz) .. " "
        msz = math.max(msz, str:len() + 2)        
        table.insert(lsfsz, str)
      end
    end

    local col = 1
    local columns = math.huge
    if component.isAvailable("gpu") and io.output() == io.stdout then
      columns = math.max(1, math.floor((component.gpu.getResolution() - 1) / (m + msz)))
    end

    if options.s then
      setColor(0xFFFFFF)
      io.write( "total " .. formatSize(tsz) .. "\n")
    end
    
    for _, d in ipairs(lsd) do
      if options.a or d:sub(1, 1) ~= "." then
        if options.s then
          setColor(0xFFFFFF)
          io.write(text.padLeft("0 ", msz))
        end
        setColor(0x66CCFF)
        io.write(text.padRight(d, m))
        if options.l or io.output() ~= io.stdout or col % columns == 0 then
          io.write("\n")
        end
        col = col + 1
      end
    end

    for ii, f in ipairs(lsf) do
      if options.a or f:sub(1, 1) ~= "." then
        if options.s then
          setColor(0xFFFFFF)
          io.write(text.padLeft(lsfsz[ii], msz))
        end
        if fs.isLink(fs.concat(path, f)) then
          setColor(0xFFAA00)
        elseif f:sub(-4) == ".lua" then
          setColor(0x00FF00)
        else
          setColor(0xFFFFFF)
        end
        io.write(text.padRight(f, m))
        if options.l then
          setColor(0xFFFFFF)
          io.write(fs.size(fs.concat(path, f)), "\n")
        elseif io.output() ~= io.stdout or col % columns == 0 then
          io.write("\n")
        end
        col = col + 1
      end
    end

    setColor(0xFFFFFF)
    if options.M then
      io.write("\n" .. tostring(#lsf) .. " File(s)")
      io.write("\n" .. tostring(#lsd) .. " Dir(s)")
    end
    if not options.l and not options.s then
      io.write("\n")
    end
  end
end
io.output():setvbuf("no")
io.output():flush()
