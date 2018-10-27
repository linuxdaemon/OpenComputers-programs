-- Modified from https://github.com/OpenPrograms/Jomik-Programs/blob/6cc725ba24e9a45a0f70a97d3031151347a6ee2f/robot/services/location/rc.d/location.lua
local component = require("component")
local location = require("location")
local sides = require("sides")
local Vector = require("vector2").Vector

local original_move = component.robot.move
local original_turn = component.robot.turn

local up_vector = Vector(0, 1, 0)

local function location_move(side, ...)
  local result = {original_move(side, ...)}

  if result[1] then
    local position, orientation = location.get()

    if side == sides.down then
      position = position - up_vector
    elseif side == sides.up then
      position = position + up_vector
    elseif side == sides.back then
      position = position - orientation
    elseif side == sides.forward then
      position = position + orientation
    end

    location.set(position, orientation)
  end

  return table.unpack(result)
end

local function location_turn(clockwise, ...)
  local result = {original_turn(clockwise, ...)}

  if result[1] then
    local position, orientation = location.get()

    if clockwise then
      orientation = Vector(-orientation.z, orientation.y, orientation.x)
    else
      orientation = Vector(orientation.z, orientation.y, -orientation.x)
    end

    location.set(position, orientation)
  end

  return table.unpack(result)
end

function start()
  component.robot.move = location_move
  component.robot.turn = location_turn

  location.set_from_gps(true)
end

function stop()
  component.robot.move = original_move
  component.robot.turn = original_turn
end
