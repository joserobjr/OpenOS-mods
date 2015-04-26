local computer = require("computer")
local event = require("event")
local fs = require("filesystem")
local shell = require("shell")
local unicode = require("unicode")
local serialization = require('serialization')

local function loadConfig()
  local env = {}
  local result, reason = loadfile('/etc/env.cfg', 't', env)
  if result then
    result, reason = xpcall(result, debug.traceback)
    if result then
      return env
    end
  end
  return nil, reason
end

local function saveConfig(conf)
  local file, reason = io.open('/etc/env.cfg', 'w')
  if not file then
    return nil, reason
  end
  for key, value in pairs(conf) do
    file:write(tostring(key) .. " = " .. serialization.serialize(value, true) .. "\n")
  end
  
  file:close()
  return true
end

local globalenv = loadConfig()

local function env()
  -- copy parent env when first requested; easiest way to keep things
  -- like number of env vars trivial (#vars).
  local data = require("process").info().data
  --[[ TODO breaking change; will require set to be a shell built-in and
            may break other programs relying on setenv being global.
  if not rawget(data, "vars") then
    local vars = {}
    for k, v in pairs(data.vars or {}) do
      vars[k] = v
    end
    data.vars = vars
  end
  --]]
  data.vars = data.vars or {}  
  for k, v in pairs(globalenv) do
    if not data.vars[k] then
      data.vars[k] = v
    end
  end
  return data.vars
end

os.execute = function(command)
  if not command then
    return type(shell) == "table"
  end
  return shell.execute(command)
end

function os.exit(code)
  error({reason="terminated", code=code~=false}, 0)
end

function os.getenv(varname)
  if varname == '#' then
    return #env()
  elseif varname ~= nil then
    return env()[varname]
  else
    return env()
  end
end

function os.setenv(varname, value)
  checkArg(1, varname, "string", "number")
  if value == nil then
    env()[varname] = nil
  else
    local success, val = pcall(tostring, value)
    if success then
      env()[varname] = val
      return env()[varname]
    else
      return nil, val
    end
  end
end

function os.exportenv(varname, value)
  if varname == '#' then
    return #globalenv
  elseif varname ~= nil then
    if value == nil then
      globalenv[varname] = nil
      os.setenv(varname, nil)
      saveConfig(globalenv)
    else
      local success, val = pcall(tostring, value)
      if success then
        globalenv[varname] = value
        os.setenv(varname, value)
        saveConfig(globalenv)
        return val
      else
        return nil, val
      end
    end
  else
    return globalenv
  end
end

function os.remove(...)
  return fs.remove(...)
end

function os.rename(...)
  return fs.rename(...)
end

function os.sleep(timeout)
  checkArg(1, timeout, "number", "nil")
  local deadline = computer.uptime() + (timeout or 0)
  repeat
    event.pull(deadline - computer.uptime())
  until computer.uptime() >= deadline
end

function os.tmpname()
  local path = os.getenv("TMPDIR") or "/tmp"
  if fs.exists(path) then
    for i = 1, 10 do
      local name = fs.concat(path, tostring(math.random(1, 0x7FFFFFFF)))
      if not fs.exists(name) then
        return name
      end
    end
  end
end

if computer.tmpAddress() then
  fs.mount(computer.tmpAddress(), os.getenv("TMPDIR") or "/tmp")
end
