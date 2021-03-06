local Inventory = {}

Inventory.__index = Inventory

setmetatable(Inventory, {
    __call = function (cls, ...)
      return cls:new(...)
    end,
  })

function Inventory:new(controller, side)
  local o = {
    controller=controller,
    side=side,
    freeSlot=1
  }
  return setmetatable(o, self)
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
  local slot = self.freeSlot >= self:size() and self.freeSlot or 1
  while slot <= self:size() do
    if self:getStackSizeInSlot(slot) == 0 then
      self.freeSlot = slot
      return self.freeSlot
    end
    slot = slot + 1
  end
end

return {
  Inventory=Inventory
}
