local shell = require("shell")

local args, options = shell.parse(...)

if #args < 1 then
  print("Usage: unset [-e] <varname>[ <varname2> [...]]")
else
  if options.e then
    for _, k in ipairs(args) do
      os.exportenv(k, nil)
    end
	else
    for _, k in ipairs(args) do
      os.setenv(k, nil)
    end
  end
end