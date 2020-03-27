local class = require("class")

local Inventory = class()

function Inventory:_init(controller, side)
  self.controller = controller
  self.side = side
  self.free_slot = 1
end

function Inventory:size()
  return self.controller.getInventorySize(self.side)
end

function Inventory:getStackInSlot(slot)
  return self.controller.getStackInSlot(self.side, slot)
end

function Inventory:getStackSizeInSlot(slot)
  return self.controller.getSlotStackSize(self.side, slot)
end

function Inventory:transferSlotToSide(...)
  return self.controller.transferItem(self.side, ...)
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
  return self.controller.getAllStacks(self.side)
end

return {
  Inventory=Inventory
}
