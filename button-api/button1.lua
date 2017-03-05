local uuid = require("uuid")

local Window = {}
Window.__index = Window
setmetatable(Window, {
  __call = function (cls, ...)
    return cls:new(...)
  end,
})

local Button = {}
Button.__index = Button
setmetatable(Button, {
  __call = function (cls, ...)
    return cls:new(...)
  end,
})

function Window:new(title)
  local o = setmetatable({}, self)
  o.title = title or ""
  return o
end

function Button:new(x, y, width, height, callback, text)
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
