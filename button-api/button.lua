local uuid = require("uuid")
local event = require("event")
local computer = require("computer")
local component = require("component")

local gpu = component.getPrimary("gpu")

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

function ButtonHandler:running()
  return self.active
end

function ButtonHandler:stop()
  self.active = false
end

function ButtonHandler:draw(button, foreground, background)
  local foreground = foreground or 0xffffff
  local background = background or 0x0000ff
  local oldFG = gpu.setForeground(foreground)
  local oldBG = gpu.setBackground(background)
  gpu.fill(button.x, button.y, button.width, button.height, " ")
  gpu.set(button.x+1, button.y+1, centerStr(button.text, button.width - 2))
  gpu.setBackground(oldBG)
  gpu.setForeground(oldFG)
end

function ButtonHandler:flashButton(button, time, fg1, bg1, fg2, bg2)
  local fg1 = fg1 or 0xffffff
  local fg2 = fg2 or 0xffffff
  local bg1 = bg1 or 0x0000ff
  local bg2 = bg2 or 0xffffff
  self:draw(button, fg2, bg2)
  os.sleep(time)
  self:draw(button, fg1, bg1)
end

function ButtonHandler:drawAll()
  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")
  for _,btn in pairs(self.buttons) do
    self:draw(btn)
  end
end

function ButtonHandler:clear()
  self.buttons = {}
end

function ButtonHandler:handler(eType, screen, x, y, mBtn, user)
  if not self.active then
    return false
  end
  for _,btn in pairs(self.buttons) do
    if (btn.x <= x) and (x <= btn.x+btn.width) then
      if (btn.y <= y) and (y <= btn.y+btn.height) then
        self:draw(btn, 0xffffff, 0xa0a0a0)
        btn.callback(btn)
        self:draw(btn, 0xffffff, 0x0000ff)
      end
    end
  end
end



return {
  Button=Button,
  ButtonHandler=ButtonHandler
}
