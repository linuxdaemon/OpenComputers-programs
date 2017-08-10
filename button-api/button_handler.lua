local event = require("event")
-- lua-objects
local class = require("class")

local button = require("button")

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

button_handler:add_variable("buttons", {})
button_handler:add_readonly_property("active", false)
button_handler:add_readonly_property("gpu", {})

button_handler:add_constructor({"table"}, function(self, gpu)
  self.privates.gpu = gpu
end)

button_handler:add_method("register_button", function(self, btn)
  if self.privates.buttons[btn.id] then
    error("Duplicate button ID!")
  end
  self.privates.buttons[btn.id] = btn
end)

button_handler:add_method("handle_touch", function(self, screen, x, y, mouse_button, user)
  if not self.active then
    return false
  end
  for _, btn in pairs(self.privates.buttons) do
    if (btn.x <= x) and (x <= btn.x + btn.width) and
        (btn.y <= y) and (y <= btn.y + btn.height) then
      if btn.is_toggleable then
        for _, b in pairs(self.privates.buttons) do
          if b.selected and btn.id ~= b.id then
            b:unselect()
            self:draw(b)
          end
        end
        btn:toggle()
        self:draw(btn)
        btn:callback()
      else
        self:flash_button(btn, nil, true)
      end
      break
    end
  end
end)

button_handler:add_method("draw", function(self, btn)
  local oldFG, oldBG
  if btn.selected then
    oldFG = self.gpu.setForeground(btn.alt_foreground)
    oldBG = self.gpu.setBackground(btn.alt_background)
  else
    oldFG = self.gpu.setForeground(btn.foreground)
    oldBG = self.gpu.setBackground(btn.background)
  end
  self.gpu.fill(btn.x, btn.y, btn.width, btn.height, " ")
  self.gpu.set(btn.x + btn.border, btn.y + btn.border, centerStr(btn.text, btn.width - 2))
  self.gpu.setBackground(oldBG)
  self.gpu.setForeground(oldFG)
end)

button_handler:add_method("flash_button", function(self, btn, time, do_callback)
  btn:select()
  self:draw(btn)
  if do_callback then
    btn:callback()
  end
  os.sleep(time)
  btn:unselect()
  self:draw(btn)
end)

button_handler:add_method("draw_all", function(self)
  self:clear_screen()
  for _, btn in pairs(self.privates.buttons) do
    self:draw(btn)
  end
end)

button_handler:add_method("clear_screen", function(self)
  local w, h = self.gpu.getResolution()
  self.gpu.fill(1, 1, w, h, " ")
end)

button_handler:add_method("clear_buttons", function(self)
  self.privates.buttons = {}
end)

button_handler:add_method("add_button", function(self, ...)
  local btn = button(...)
  self:register_button(btn)
  return btn
end)

button_handler:add_method("reset", function(self)
  for _, btn in pairs(self.privates.buttons) do
    if btn.selected then
      btn:unselect()
      self:draw(btn)
    end
  end
end)

button_handler:add_method("stop", function(self)
  self.privates.active = false
end)

button_handler:add_method("loop", function(self)
  self.privates.active = true
  while self.active do
    self:handle_touch(select(2, event.pull("touch")))
  end
end)

return button_handler
