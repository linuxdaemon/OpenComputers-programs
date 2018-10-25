local class = require("class")
local vector = {}

local Vector = class()

function Vector:_init(x, y, z)
  self.x = x or 0
  self.y = y or 0
  self.z = z or 0
end

function Vector:add(other)
  return Vector(
    self.x + other.x,
    self.y + other.y,
    self.z + other.z
  )
end

function Vector:sub(other)
  return Vector(
    self.x - other.x,
    self.y - other.y,
    self.z - other.z
  )
end

function Vector:mul(scalar)
  return Vector(
    self.x * scalar,
    self.y * scalar,
    self.z * scalar
  )
end

function Vector:dot(other)
  local a = self.x * other.x
  local b = self.y * other.y
  local c = self.z * other.z
  return a + b + c
end

function Vector:cross(other)
  return Vector(
      (self.y * other.z) - (self.z * other.y),
      (self.z * other.x) - (self.x * other.z),
      (self.x * other.y) - (self.y * other.x)
    )
end

function Vector:length()
  return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector:normalize()
  return self:mul(1 / self:length())
end

function Vector:round(tolerance)
  tolerance = tolerance or 1.0
  local function _calc(n)
    return math.floor((n + (tolerance * 0.5)) / tolerance) * tolerance
  end
  return Vector(
    _calc(self.x),
    _calc(self.y),
    _calc(self.z)
  )
end

function Vector:tostring()
  return string.format("%s,%s,%s", self.x, self.y, self.z)
end

Vector.instance_meta.__add = Vector.add
Vector.instance_meta.__sub = Vector.sub
Vector.instance_meta.__mul = Vector.mul
Vector.instance_meta.__unm = function(self) return self:mul(-1) end
Vector.instance_meta.__tostring = Vector.tostring

function vector.new(x, y, z)
  return Vector(x, y, z)
end

vector.Vector = Vector

return vector
