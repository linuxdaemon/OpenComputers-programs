local component = require("component")
local term = require("term")
local button = require("button")

local dialer = component.rftools_dialing_device
local gpu = component.gpu

local receivers = {}

local transmitter = dialer.getTransmitters()[1]
local btnScreen

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
  local ratio = a / b -- 1
  local inverse = math.pow(ratio, -1)
  if (w * ratio) <= h then
    gpu.setResolution(w*2, w * ratio)
  elseif (h / ratio) <= w then
    gpu.setResolution((h / ratio)*2, h)
  else
    error("Error setting resolution")
  end
end

local function loadRx()
  receivers = dialer.getReceivers()
end

local function dial(receiver)
  dialer.dial(transmitter, receiver, receiver.dimension, false)
end

local function interrupt()
  dialer.interrupt(transmitter)
end

local function dialCBGen(i)
  return function()
    dial(receivers[i])
  end
end

local function drawButtons()
  local rxNames = {}
  for _, receiver in ipairs(receivers) do
    rxNames[#rxNames + 1] = receiver.name
  end
  local oldScreen = gpu.getScreen()
  gpu.bind(btnScreen.address)
  alignResolution()
  term.clear()
  local id = button.list(rxNames, 0x0000ff, 0xffffff, gpu)

  term.clear()
  print("Selected: " .. receivers[id].name)
  gpu.bind(oldScreen)
end

loadRx()
getButtonScreen()
drawButtons()
os.sleep(5)
