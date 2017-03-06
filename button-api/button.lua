local uuid = require("uuid")
local event = require("event")
local computer = require("computer")

local Button = {}
Button.__index = Button
setmetatable(Button, {
  __call = function (cls, ...)
    return cls:new(...)
  end,
})

local ButtonHandler = {}
ButtonHandler.__index = ButtonHandler
setmetatable(ButtonHandler, {
  __call = function (cls, ...)
    return cls:new(...)
  end,
})

local function centerStr(s, len)
  local i = len - s:len()
  if i == 0 then
    return s
  end
  local pre = math.floor(i / 2)
  local post = math.ceil(i / 2)
  return string.rep(" ", pre) .. s
end

function Button:new(x, y, width, height, callback, text)
  checkArg(1, x, "number")
  checkArg(2, y, "number")
  checkArg(3, width, "number")
  checkArg(4, height, "number")
  local o = {
    x=x,
    y=y,
    width=width,
    height=height,
    callback=callback,
    text=text,
    id=uuid.next()
  }
  return setmetatable(o, self)
end

function ButtonHandler:new()
  return setmetatable({buttons={}, active=false}, self)
end

function ButtonHandler:register(button)
  if not(self.buttons[button.id] == nil) then
    error("Attempted to register button with conflicting ID")
  end
  self.buttons[button.id] = button
end

function ButtonHandler:start()
  self.active = true
  event.listen("touch", function (...) return self:handler(...) end)
end

function ButtonHandler:stop()
  self.active = false
end

function ButtonHandler:draw(gpu)
  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")
  for _,btn in pairs(self.buttons) do
    local oldBG = gpu.setBackground(0x0000ff)
    local oldFG = gpu.setForeground(0xffffff)
    gpu.fill(btn.x, btn.y, btn.width, btn.height, " ")
    gpu.set(btn.x+1, btn.y+1, centerStr(btn.text, btn.width - 2))
    gpu.setBackground(oldBG)
    gpu.setForeground(oldFG)
  end
end

function ButtonHandler:handler(eType, screen, x, y, mBtn, user)
  if not self.active then
    return false
  end
  for _,btn in pairs(self.buttons) do
    if (btn.minX <= x) and (x <= btn.maxX) then
      if (btn.minY <= y) and (y <= btn.maxY) then
        computer.beep(1000, 1)
        btn.callback()
      end
    end
  end
end



return {
  Button=Button,
  ButtonHandler=ButtonHandler
}
