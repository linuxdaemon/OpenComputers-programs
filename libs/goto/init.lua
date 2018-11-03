local location = require("location")
local robot = require("robot")

local lib = {}

function lib.move_vector(vector)
  local function go_forward(n)
    for _=1,math.abs(n) do
      while not robot.forward() do
        while not robot.up() do
          robot.swingUp()
        end
        vector.y = vector.y + 1
      end
    end
  end

  local function do_rotate(invert_axis)
    invert_axis = invert_axis or false
    local x_name, z_name = "x", "z"
    local left_func, right_func = robot.turnLeft, robot.turnRight
    if invert_axis then
      x_name, z_name = z_name, x_name
      left_func, right_func = right_func, left_func
    end
    local _, facing = location.get()
    if vector[x_name] ~= 0 then
      -- Are we facing along the X axis?
      if facing[x_name] ~= 0 then
        -- Are we facing the right way on the X axis?
        if not((facing[x_name] > 0) == (vector[x_name] > 0)) then
          robot.turnAround()
        end
      elseif (facing[z_name] > 0) == (vector[x_name] > 0) then
        left_func()
      else
        right_func()
      end
    end
  end

  do_rotate()

  go_forward(vector.x)

  do_rotate(true)

  go_forward(vector.z)

  local function move_y(invert)
    invert = invert or false
    local move, swing
    if invert then
      move, swing = robot.down, robot.swingDown
    else
      move, swing = robot.up, robot.swingUp
    end
    for _=1,math.abs(vector.y) do
      while not move() do
        swing()
      end
    end
  end

  move_y(vector.y < 0)
end

function lib.goto_pos(position)
  if not position then
    error("Can not move to nil location")
  end
  local loc, _ = location.get()
  lib.move_vector(position - loc)
end

function lib.get_waypoint(name)
  local waypoints = dofile("waypoints.lua")
  return waypoints[name] or error("No such waypoint: " .. name)
end

function lib.goto_waypoint(name)
  return lib.goto_pos(lib.get_waypoint(name))
end

return lib
