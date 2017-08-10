-- lua-objects
local class = require("class")

local matter_transmitter = class("matter_transmitter")

matter_transmitter:add_readonly_property("dialer", {})
matter_transmitter:add_variable("raw_tbl", {})

matter_transmitter:add_constructor({"table", "table"}, function(self, dialer, tbl)
  self.privates.dialer = dialer
  self.privates.raw_tbl = tbl
end)

matter_transmitter:add_getter("position", function(self)
  return self.raw_tbl.position
end)

matter_transmitter:add_getter("name", function(self)
  return self.raw_tbl.name
end)

matter_transmitter:add_getter("is_dialed", function(self)
  return self.raw_tbl.dialed or false
end)

matter_transmitter:add_method("dial_to", function(self, receiver)
  return self.dialer:dial(self, receiver)
end)

matter_transmitter:add_method("dial_once_to", function(self, receiver)
  return self.dialer:dial_once(self, receiver)
end)

return matter_transmitter
