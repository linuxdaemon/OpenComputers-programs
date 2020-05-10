local comp = require("component")
local class = require("class")

local SideWrapper = class("SideWrapper")

function SideWrapper:_init(address, side)
  self.address = address
  self.side = side
end

function SideWrapper.from_proxy(component, side)
  return SideWrapper(component.address, side)
end

function SideWrapper:invoke(method, ...)
  return comp.invoke(self.address, method, self.side, ...)
end

return {
  SideWrapper=SideWrapper,
}
