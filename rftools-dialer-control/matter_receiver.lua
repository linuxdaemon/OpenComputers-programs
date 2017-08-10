-- lua-objects
local class = require("class")

local matter_receiver = class("matter_receiver")

matter_receiver:add_readonly_property("dialer", {})
matter_receiver:add_readonly_property("raw_tbl", {})

matter_receiver:add_constructor({"dialing_device", "table"}, function(self, dialer, tbl)
  self.privates.dialer = dialer
  self.privates.raw_tbl = tbl
end)

matter_receiver:add_getter("position", function(self)
  return self.raw_tbl.position
end)

matter_receiver:add_getter("name", function(self)
  return self.raw_tbl.name
end)

matter_receiver:add_getter("dimension", function(self)
  return self.raw_tbl.dimension
end)

matter_receiver:add_getter("dimension_name", function(self)
  return self.raw_tbl.dimensionName
end)

return matter_receiver
