local vector = require("vector2")
local libgoto = require("goto")

local args = {...}

local function main()
  if #args == 1 then
    libgoto.goto_waypoint(args[1])
  elseif #args >= 3 then
    libgoto.goto_pos(vector.new(args[1], args[2], args[3]))
  else
    error("unknown args")
  end
end

main()
