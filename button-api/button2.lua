local component = require("component")
local event = require("event")

--local gpu = component.gpu

local button = {}

--local buttons = {}

--[[function button.addButton(x, y, x1, y1, callback)
  buttons[#buttons + 1] = {minX = x, minY = y, maxX = x1, maxY = y1, callback = callback}
end

local function buttonHandler(eType, screenID, x, y, btn, user)
  for _,button in ipairs(buttons) do
    if (button.minX <= x) and (x <= button.maxX) and (button.minY <= y) and (y <= button.maxY) then
      button.callback(screenID, btn, user)
      break
    end
  end
end]]

local function centerStr(s, len)
  local i = len - s:len()
  if i == 0 then
    return s
  end
  local pre = math.floor(i / 2)
  local post = math.ceil(i / 2)
  return string.rep(" ", pre) .. s
end

function button.list(list, btnColor, txtColor, gpu)
  local longest = 16
  for _,s in ipairs(list) do
    if s:len() > longest then longest = s:len() end
  end
  
  local scWidth, scHeight = gpu.getResolution()
  local columnWidth = longest + 4
  local rowHeight = 5
  local i = 1
  local x, y = 1, 1
  local buttons = {}
  while y < (scHeight - rowHeight) do
    x = 1
    while x < (scWidth - columnWidth) do
      if i > #list then
        break
      end
      buttons[#buttons + 1] = {title=list[i], id=i, minX=x+1, minY=y+1, maxX=x+columnWidth-1, maxY=y+rowHeight-1}
      local oldBG = gpu.setBackground(btnColor)
      local oldFG = gpu.setForeground(txtColor)
      gpu.fill(x+1, y+1, columnWidth - 2, rowHeight - 2, " ")
      gpu.set(x+2, y+2, centerStr(list[i], longest))
      gpu.setBackground(oldBG)
      gpu.setForeground(oldFG)
      i = i + 1
      x = x + columnWidth
    end
    y = y + rowHeight
  end
  while true do
    local _, _, x, y = event.pull("touch")
    for _,btn in ipairs(buttons) do
      if (btn.minX <= x) and (x <= btn.maxX) then
        if (btn.minY <= y) and (y <= btn.maxY) then
          return btn.id
        end
      end
    end
  end
end

return button