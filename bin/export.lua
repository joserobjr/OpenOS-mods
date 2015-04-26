local args = {...}

if #args < 1 then
  for k,v in pairs(os.exportenv()) do
    io.write(k .. "='" .. string.gsub(v, "'", [['"'"']]) .. "'\n")
  end
else
  local count = 0 
  for _, expr in ipairs(args) do
    local k, v = string.match(expr, "(.-)=(.*)")
    if v then
      os.exportenv(k, v)
    else
      if count == 0 then
        for i = 1, os.getenv('#') do
          os.setenv(i, nil)
        end
      end
      count = count + 1
      os.setenv(count, expr)
    end
  end
end
