local gps = require("gps2")
local thread = require("thread")

local t

function start()
  local x, y, z
  if args then
    print("Using static location")
    x = args.x
    y = args.y
    z = args.z
  else
    x, y, z = gps.locate()
    if not x then
      print("Unable to find location")
      return
    end
  end
  t = thread.create(gps.host, x, y, z)
  t:detach()
end

function stop()
  if t then
    t:kill()
    t = nil
  end
end
