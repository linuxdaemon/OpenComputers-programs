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

function Button:new(x, y, width, height, callback, text, toggleable)
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
    selected=false,
    toggle=toggleable or false,
    id=uuid.next(),
    foreground=0xFFFFFF,
    background=0x0000FF,
    sForeground=0xFFFFFF,
    sBackground=0xA0A0A0,
    text_align="center",
    border=1
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

function ButtonHandler:draw(button)
  local oldFG, oldBG
  if button.selected then
    oldFG = gpu.setForeground(button.sForeground)
    oldBG = gpu.setBackground(button.sBackground)
  else
    oldFG = gpu.setForeground(button.foreground)
    oldBG = gpu.setBackground(button.background)
  end
  gpu.fill(button.x, button.y, button.width, button.height, " ")
  gpu.set(button.x+button.border, button.y+button.border, centerStr(button.text, button.width - 2))
  gpu.setBackground(oldBG)
  gpu.setForeground(oldFG)
end

function ButtonHandler:flashButton(button, time)
  button.selected = true
  self:draw(button)
  os.sleep(time)
  button.selected = false
  self:draw(button)
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
        if btn.toggle then
          for _,b in pairs(self.buttons) do
            if b.selected and not(b.id == btn.id) then
              b.selected = false
              self:draw(b)
            end
          end
          btn.selected = not btn.selected
          self:draw(btn)
          btn.callback(btn)
        else
          btn.selected = true
          self:draw(btn)
          btn.callback(btn)
          btn.selected = false
          self:draw(btn)
        end
      end
    end
  end
end



return {
  Button=Button,
  ButtonHandler=ButtonHandler
}
