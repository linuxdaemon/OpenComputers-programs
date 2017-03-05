local uuid = require("uuid")
local event = require("event")

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

function Button:new(text, callback)
  local o = {
    x=x,
    y=y,
    width=width,
    heigfht=height,
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
  event.listen("touch", function (...) return ButtonHandler:handler(...) end)
end

function ButtonHandler:stop()
  self.active = false
end

function ButtonHandler:handler(eType, screen, x, y, mBtn, user)
  if not self.active then
    return false
  end
  for _,btn in ipairs(self.buttons) do
    if (btn.minX <= x) and (x <= btn.maxX) then
      if (btn.minY <= y) and (y <= btn.maxY) then
        btn.callback()
      end
    end
  end
end
