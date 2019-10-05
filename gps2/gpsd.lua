local gps = require("gps2")
local thread = require("thread")

local t

function start()
  if loc then
    t = thread.create(gps.host, loc.x, loc.y, loc.z)
  else
    t = thread.create(gps.host)
  end
end

function stop()
  if t then
    t:kill()
    t = nil
  end
end
