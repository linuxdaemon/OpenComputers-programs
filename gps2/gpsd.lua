local gps = require("gps2")
local thread = require("thread")

local t

function start()
  local x, y, z
  if loc then
    print("Using static location")
    x = loc.x
    y = loc.y
    z = loc.z
  else
    x, y, z = gps.locate()
    if not x then
      print("Unable to find location")
      return
    end
  end
  t = thread.create(gps.host, x, y, z)
end

function stop()
  if t then
    t:kill()
    t = nil
  end
end
