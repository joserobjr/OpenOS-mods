local component = require("component")
local term = require("term")
local shell = require("shell")
local colors = require("colors")

local args, options = shell.parse(...)
if options.c and term.isAvailable() then
  component.gpu.setForeground( colors.white, true)
  component.gpu.setBackground( colors.black, true)
end
term.clear()