-- lua-objects
local class = require("class")
local matter_transmitter = require("matter_transmitter")
local matter_receiver = require "matter_receiver"

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
  local receivers = self.component.getTransmitters()
  for i, receiver in ipairs(receivers) do
    receivers[i] = matter_transmitter(self, receiver)
  end
  return receivers
end)

dialing_device:add_method("dial", function(self, transmitter, receiver, once)
  if receiver == nil or type(receiver) == "boolean" then
    -- Shift all parameters and set the transmitter to the default
    once = receiver
    receiver = transmitter
    transmitter = self.default_transmitter
  end
  if once then
    return self.component.dial(transmitter.position, receiver.position, receiver.dimension, once)
  else
    return self.component.dial(transmitter.position, receiver.position, receiver.dimension)
  end
end)

dialing_device:add_method("dial_once", function(self, transmitter, receiver)
  if receiver == nil then
    -- Shift all parameters and set the transmitter to the default
    receiver = transmitter
    transmitter = self.default_transmitter
  end
  return self:dial(transmitter, receiver, true)
end)

dialing_device:add_method("interrupt", function(self, transmitter)
  transmitter = transmitter or self.default_transmitter
  return self.component.interrupt(transmitter.position)
end)

return dialing_device
