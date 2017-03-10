local inv = require("libinventory")
local component = require("component")
local sides = require("sides")

local invctl = component.transposer

local inInv = inv.Inventory(invctl, sides.south)
local outInv = inv.Inventory(invctl, sides.east)
local trashInv = inv.Inventory(invctl, sides.up)

local function sort()
  for i=1,inInv:size() do
    local stack = inInv:getStackInSlot(i)
    if stack and stack.enchantments and #stack.enchantments > 0 then
      if not inInv:transferSlotToSide(i, outInv.side) then
        inInv:transferSlotToSide(i, trashInv.side)
      end
    else
      inInv:transferSlotToSide(i, trashInv.side)
    end
  end
end

local function main()
  while true do
    sort()
    os.sleep(.1)
  end
end

main()
