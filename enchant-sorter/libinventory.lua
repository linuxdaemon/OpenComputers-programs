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
  local count = count or 1
  return self.controller.transferItem(self.side, ...)
end

function Inventory:getNextFreeSlot()
  local slot = self.freeSlot
  for i=1,self:size() do
    if slot > self:size() then slot = 1 end
    if not self:getStackInSlot(slot) then
      return self.freeSlot = slot
    end
    slot = slot + 1
  end
end

return {
  Inventory=Inventory
}
