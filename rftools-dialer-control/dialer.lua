local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local thread = require("thread")

-- Button API
local button_handler = require("button_handler")
local dialing_device = require("dialing_device")

local dialer = dialing_device(component.getPrimary("rftools_dialing_device"))
local gpu = component.getPrimary("gpu")

local receivers = {}

local bh = nil

local function log(line)
  print(line)
end

local function align_resolution()
  local sizeRatio = 1
  local screen = component.proxy(gpu.getScreen())
  local w, h = gpu.maxResolution()
  w = w / 2
  local a, b = screen.getAspectRatio()
  local ratio = a / b
  local inverse = math.pow(ratio, -1)
  if (h * ratio) <= w then
    gpu.setResolution(((h * ratio)*2)/sizeRatio, h/sizeRatio)
  elseif (w * inverse) <= h then
    gpu.setResolution((w*2)/sizeRatio, (w * inverse)/sizeRatio)
  else
    error("Error setting resolution")
  end
end

local function clear_screens()
  local oldScreen = gpu.getScreen()
  for screen in component.list('screen', true) do
    gpu.bind(screen)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
  end
  gpu.bind(oldScreen)
end

local function load_receivers()
  receivers = {}
  for _, rx in ipairs(dialer.receivers) do
    receivers[#receivers + 1] = rx
  end
end

local function at_exit()
  if bh and bh:running() then bh:stop() end
  term.clear()
end

local function interrupt()
  local res, err = dialer:interrupt()
  if not res then
    at_exit()
    error(err)
  end
  if bh then
    bh:reset()
  end
end

local function dial(receiver)
  local res, err = dialer:dial_once(receiver)
  if not res then
    at_exit()
    error(err)
  end
end

local function dialCBGen(rx)
  return function(btn)
    if btn.selected then
      dial(rx)
    else
      interrupt()
    end
  end
end

local reload -- forward declaration for buttons

local function draw_buttons()
  log("Drawing buttons")
  align_resolution()
  term.clear()
  local longest = 5
  local maxLen = 25
  for _, rx in ipairs(receivers) do
    if rx.name:len() > longest then
      longest = rx.name:len()
    end
  end
  longest = longest < maxLen and longest or maxLen
  if bh then
    bh:clear()
  end
  bh = bh or button_handler(gpu)

  local scWidth, scHeight = gpu.getResolution()
  local scHeight = scHeight - 2
  local columnWidth = longest + 4
  local rowHeight = 5
  local x, y = 1, 1
  for _, rx in ipairs(receivers) do
    if x > (scWidth - columnWidth) then
      x = 1
      y = y + rowHeight
    end
    if y > (scHeight - rowHeight) then
      error("Screen size maxed: " .. tostring(x) .. " " .. tostring(y))
    end
    local new_button = bh:add_button(x + 1, y + 1, columnWidth - 2, rowHeight - 2, dialCBGen(rx), rx.name:sub(1, longest))
    new_button.is_toggleable = true
    x = x + columnWidth
  end
  local reloadButtonTxt = "Reload"
  local reload_button = bh:add_button(1, scHeight - 3, reloadButtonTxt:len() + 2, 3, reload, reloadButtonTxt)
  local intButtonTxt = "Interrupt"
  local int_button = bh:add_button(scWidth - (intButtonTxt:len()+2), scHeight - 3, intButtonTxt:len() + 2, 3, interrupt, intButtonTxt)
  bh:draw_all()
end

reload = function()
  interrupt()
  load_receivers()
  draw_buttons()
end

local function error_wrap(func, ...)
  local result = {xpcall(func, debug.traceback, ...)}
  if not result[1] then
    io.stderr:write(result[2], '\n')
  else
    return table.unpack(result, 3, #result)
  end
end

local function main()
  clear_screens()
  reload()
  bh:loop()
end

local function shutdown()
  event.pull("interrupted")
  at_exit()
end

local function run()
  local funcs = {
    shutdown,
    main,
  }
  local threads = {}
  for _, func in ipairs(funcs) do
    threads[#threads + 1] = thread.create(error_wrap, func)
  end
  thread.waitForAny(threads)
  os.exit(0)
end

run()
