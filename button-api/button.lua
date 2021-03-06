local uuid = require("uuid")
local event = require("event")
local computer = require("computer")
local component = require("component")

-- lua-objects
local class = require("class")

local gpu = component.getPrimary("gpu")

local button = class("button")

local button_handler = class("button_handler")

local function centerStr(s, len)
  local i = len - s:len()
  if i == 0 then
    return s
  end
  local pre = math.floor(i / 2)
  local post = math.ceil(i / 2)
  return string.rep(" ", pre) .. s
end

button:add_variable("position", {
  x = -1,
  y = -1,
})

button:add_variable("size", {
  width = -1,
  height = -1,
})

button:add_readonly_property("text", "")
button:add_readonly_property("id", "")
button:add_readonly_property("border", 1)
button:add_readonly_property("selected", false)
button:add_readonly_property("foreground", 0xFFFFFF)
button:add_readonly_property("background", 0x0000FF)
button:add_readonly_property("alt_foreground", 0xFFFFFF)
button:add_readonly_property("alt_background", 0xA0A0A0)
button:add_readonly_property("text_align", "center")
button:add_readonly_property("callback", function() end)

button:add_property("is_toggleable", false)

button:add_constructor({"number", "number", "number", "number", "function", "string"}, function(self, x, y, width, height, callback, text)
  self.privates.position.x = x
  self.privates.position.y = y
  self.privates.size.width = width
  self.privates.size.height = height
  self.privates.text = text
  self.privates.id = uuid.next()
  self.privates.callback = callback
end)

button:add_method("select", function(self)
  self.privates.selected = true
end)

button:add_method("unselect", function(self)
  self.privates.selected = false
end)

button:add_method("toggle", function(self)
  self.privates.selected = not self.privates.selected
end)

button:add_getter("width", function(self) return self.privates.size.width end)
button:add_getter("height", function(self) return self.privates.size.height end)
button:add_getter("x", function(self) return self.privates.position.x end)
button:add_getter("y", function(self) return self.privates.position.y end)

return button
