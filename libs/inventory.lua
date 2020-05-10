local class = require("class")
local side_wrap = require("side_wrap")

local Inventory = class("Inventory")

function Inventory:_init(controller, side)
  self.controller = controller
  self.side = side
  self.proxy = side_wrap.SideWrapper.from_proxy(controller, side)
  self.free_slot = 1
end

function Inventory:size()
  return self.proxy:invoke("getInventorySize")
end

function Inventory:getStackInSlot(slot)
  return self.proxy:invoke("getStackInSlot", slot)
end

function Inventory:getStackSizeInSlot(slot)
  return self.proxy:invoke("getSlotStackSize", slot)
end

function Inventory:transferSlotToSide(...)
  return self.proxy:invoke("transferItem", ...)
end

function Inventory:getNextFreeSlot()
  local slot = self.free_slot >= self:size() and self.free_slot or 1
  while slot <= self:size() do
    if self:getStackSizeInSlot(slot) == 0 then
      self.free_slot = slot
      return self.free_slot
    end
    slot = slot + 1
  end
end

function Inventory:getAllStacks()
  return self.proxy:invoke("getAllStacks")
end

return {
  Inventory=Inventory
}
