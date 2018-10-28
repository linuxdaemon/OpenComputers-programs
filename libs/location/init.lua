-- Modified from https://github.com/OpenPrograms/Jomik-Programs/blob/6cc725ba24e9a45a0f70a97d3031151347a6ee2f/programs.cfg

local robot = require("robot")
local filesystem = require("filesystem")
local serialization = require("serialization")
local gps = require("gps2")
local vector = require("vector2")
local Vector = vector.Vector

local DATA_PATH = "/var/location/"
local DATA_FILE = "location.dat"
local DEFAULT_POSITION, DEFAULT_ORIENTATION = Vector(0, 0, 0), Vector(1, 0, 0)

local location = {}
local position, orientation

local function ensureDataDirectory()
  if not filesystem.exists(DATA_PATH) then
    return filesystem.makeDirectory(DATA_PATH)
  end
  return filesystem.isDirectory(DATA_PATH)
end

local function saveData()
  assert(ensureDataDirectory(),
    "an error occurred trying to create directory at " .. DATA_PATH)
  local stream = io.open(DATA_PATH .. DATA_FILE, "w")
  stream:write(serialization.serialize(position),
    "\n", serialization.serialize(orientation))
  stream:close()
end

local function loadData()
  local stream = io.open(DATA_PATH .. DATA_FILE, "r")

  local serialized_position, serialized_orientation
  -- read file if it exists
  if stream then
    serialized_position = stream:read("*l")
    serialized_orientation = stream:read("*l")
    stream:close()
  end

  -- if we got some text, unserialize it
  if serialized_position and serialized_orientation then
    position = vector.from(serialization.unserialize(serialized_position))
    orientation = vector.from(serialization.unserialize(serialized_orientation))
  end

  return position, orientation
end

function location.set(pos, ori)
  position, orientation = pos, ori
  saveData()
end

function location.get()
  if not position then
    -- Try to load the position and orientation from file.
    position, orientation = loadData()
    if not position then
      position, orientation = DEFAULT_POSITION, DEFAULT_ORIENTATION
    end
  end

  return position, orientation
end

local function get_gps_vector()
  local x, y, z = gps.locate(5)
  if x == nil then
    error("Unable to get GPS location")
  end
  return Vector(x, y, z)
end

function location.set_from_gps(set_orientation)
  position = get_gps_vector()
  if set_orientation then
    orientation = DEFAULT_ORIENTATION
    local pos1 = vector.from(position)
    while not robot.forward() do
      robot.up()
      pos1 = vector.from(position)
    end
    -- wait one second for movement to complete
    os.sleep(1)
    local pos2 = get_gps_vector()
    orientation = pos2 - pos1
  end
  saveData()
end

return location
