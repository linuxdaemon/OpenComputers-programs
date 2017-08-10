-- lua-objects
local class = require("class")
local matter_transmitter = require("matter_transmitter")
local matter_receiver = require("matter_receiver")

local dialing_device = class("dialing_device")

dialing_device:add_readonly_property("component", {})

dialing_device:add_constructor({"table"}, function(self, component)
  self.privates.component = component
end)

dialing_device:add_getter("transmitters", function(self)
  local transmitters = self.component.getTransmitters()
  for i, transmitter in ipairs(transmitters) do
    transmitters[i] = matter_transmitter(self, transmitter)
  end
  return transmitters
end)

dialing_device:add_getter("default_transmitter", function(self)
  return self.transmitters[1]
end)

dialing_device:add_getter("receivers", function(self)
  local receivers = self.component.getReceivers()
  for i, receiver in ipairs(receivers) do
    receivers[i] = matter_transmitter(self, receiver)
  end
  return receivers
end)

dialing_device:add_overloaded_method("dial", {"transmitter", "receiver", "boolean"}, function(self, transmitter, receiver, once)
  if once then
    return self.component.dial(transmitter.position, receiver.position, receiver.dimension, once)
  else
    return self.component.dial(transmitter.position, receiver.position, receiver.dimension)
  end
end)

dialing_device:add_overloaded_method("dial", {"transmitter", "receiver"}, function(self, transmitter, receiver)
  return self:dial(transmitter, receiver, false)
end)

dialing_device:add_overloaded_method("dial", {"receiver", "boolean"}, function(self, receiver, once)
  return self:dial(self.default_transmitter, receiver, once)
end)

dialing_device:add_overloaded_method("dial", {"receiver"}, function(self, receiver)
  return self:dial(self.default_transmitter, receiver)
end)

dialing_device:add_overloaded_method("dial_once", {"transmitter", "receiver"}, function(self, transmitter, receiver)
  return self:dial(transmitter, receiver, true)
end)

dialing_device:add_overloaded_method("dial_once", {"receiver"}, function(self, receiver)
  return self:dial(self.default_transmitter, receiver, true)
end)

dialing_device:add_overloaded_method("interrupt", {"transmitter"}, function(self, transmitter)
  return self.component.interrupt(transmitter.position)
end)

dialing_device:add_overloaded_method("interrupt", {}, function(self)
  return self:interrupt(self.default_transmitter)
end)

return dialing_device
