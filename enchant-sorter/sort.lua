local inv = require("libinventory")
local component = require("component")
local sides = require("sides")

local invctl = component.transposer

local inInv = inv.Inventory(invctl, sides.south)
local outInv = inv.Inventory(invctl, sides.east)
local trashInv = inv.Inventory(invctl, sides.up)

local function sort()
  for i=1,inInv:size() do
    print("Looking for stack in slot " .. tostring(i))
    local stack = inInv:getStackInSlot(i)
    if stack then
      if stack.enchantments and #stack.enchantments > 0 then
        print("Attempting to move item to output")
        if not inInv:transferSlotToSide(outInv.side, stack.size, i, outInv:getNextFreeSlot()) then
          print("Output full, trashing item")
          inInv:transferSlotToSide(trashInv.side, stack.size, i, 1)
        end
      else
        inInv:transferSlotToSide(trashInv.side, stack.size, i, 1)
      end
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
