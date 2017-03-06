local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local button = require("button")

local dialer = component.rftools_dialing_device
local gpu = component.gpu

local receivers = {}

local caughtInterrupt = false
local transmitter = dialer.getTransmitters()[1]
local startingScreen = gpu.getScreen()
local btnScreen
local bh = nil

local function getButtonScreen()
  for screen in component.list('screen', true) do
    if #component.invoke(screen, "getKeyboards") == 0 then
      btnScreen = component.proxy(screen)
      return btnScreen
    end
  end
end

local function alignResolution()
  local screen = component.proxy(gpu.getScreen())
  local w, h = gpu.maxResolution()
  w = w / 2
  local a, b = screen.getAspectRatio()
  local ratio = a / b
  local inverse = math.pow(ratio, -1)
  if (h * ratio) <= w then
    gpu.setResolution((h * ratio)*2, h)
  elseif (w * inverse) <= h then
    gpu.setResolution(w*2, w * inverse)
  else
    error("Error setting resolution")
  end
end

local function clearScreens()
  local oldScreen = gpu.getScreen()
  for screen in component.list('screen', true) do
    gpu.bind(screen)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
  end
  gpu.bind(oldScreen)
end

local function loadRx()
  receivers = dialer.getReceivers()
end

local function dial(receiver)
  local res, err = dialer.dial(transmitter, receiver, receiver.dimension, false)
  if not res then
    atExit()
    error(err)
  end
end

local function interrupt()
  dialer.interrupt(transmitter)
end

local function dialCBGen(rx)
  return function()
    computer.beep(1000)
    dial(rx)
  end
end

local function drawButtons()
  gpu.bind(btnScreen.address)
  alignResolution()
  term.clear()
  local longest = 16
  for _,rx in ipairs(receivers) do
    if rx.name:len() > longest then longest = rx.name:len() end
  end
  bh = button.ButtonHandler:new()

  local scWidth, scHeight = gpu.getResolution()
  local columnWidth = longest + 4
  local rowHeight = 5
  local x, y = 1, 1
  for _,rx in ipairs(receivers) do
    if x > (scWidth - columnWidth) then
      x = 1
      y = y + rowHeight
    end
    if y > (scHeight - rowHeight) then
      error("Screen size maxed: " .. tostring(x) .. " " .. tostring(y))
    end
    bh:register(button.Button:new(x+1, y+1, columnWidth-2, rowHeight-2, dialCBGen(rx), rx.name))
    x = x + columnWidth
  end

  --bh:start()
  bh:draw(gpu)
  gpu.bind(startingScreen)
end

local function atExit()
  if bh then bh:stop() end
  gpu.bind(startingScreen)
  term.clear()
end

local function interruptHandler()
  atExit()
  os.exit(0)
end

local function registerInterruptHandler()
  event.listen("interrupted", interruptHandler)
end

local function mainLoop()
  bh.active = true
  while true do
    local id, screen, x, y, mBtn, user = event.pullMultiple("interrupted", "touch")
    if id == "interrupted" then
      interruptHandler()
    elseif id == "touch" then
      bh:handler(id, screen, x, y, mBtn, user)
    end
  end
end

clearScreens()
loadRx()
getButtonScreen()
drawButtons()
mainLoop()
