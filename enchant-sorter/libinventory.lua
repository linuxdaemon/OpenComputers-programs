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
    side=side
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

function Inventory:transferSlotToSide(fromSlot, toSide, toSlot, count)
  local count = count or 1
  return self.controller.transferItem(self.side, toSide, count, fromSlot, toSlot)
end

return {
  Inventory=Inventory
}
