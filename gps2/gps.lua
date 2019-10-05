local libgps = require("gps2")

local args = {...}

local function get_loc()
  local x, y, z = libgps.locate()
  print(string.format("Current Position: %d, %d, %d", x, y, z))
end

local function host_gps()
  if #args == 4 then
    local x = tonumber(args[2])
    local y = tonumber(args[3])
    local z = tonumber(args[4])
    libgps.host(x, y, z)
  else
    libgps.host()
  end
end

local subcmds = {
  get=get_loc,
  host=host_gps,
}

local function showUsage()
  print([[Usage: gps <command>

Commands:
  get                 Show the current location of this computer
  host [x] [y] [z]    Host a GPS server, optionally setting the coordinates for it]])
end

local function main()
  local cmd = args[1]
  local handler = subcmds[cmd]
  if handler == nil then
    showUsage()
  else
    handler()
  end
end

main()
