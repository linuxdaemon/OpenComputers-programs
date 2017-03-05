local component = require("component")
local term = require("term")

local button = dofile("/home/lib/button.lua")

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
  --local oldScreen = gpu.getScreen()
  --gpu.bind(screen.address)
  local screen = component.proxy(gpu.getScreen())
  local w, h = gpu.maxResolution() -- 160 50
  w = w / 2
  local a, b = screen.getAspectRatio() -- 5 5 
  local ratio = a / b -- 1
  local inverse = math.pow(ratio, -1) -- 1
  if (w * ratio) <= h then 
    gpu.setResolution(w*2, w * ratio)
  elseif (h / ratio) <= w then
    gpu.setResolution((h / ratio)*2, h)
  else
    error("Error setting resolution")
  end
  local w, h = gpu.getResolution()
  --local oldBG = gpu.setBackground(0xff0000)
  --gpu.fill(1, 1, w, h, " ")
  --gpu.setBackground(oldBG)
  --print(ratio)
  --print("New Resolution: " .. tostring(w) .. "x" .. tostring(h))
  --os.sleep(5)
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
--alignResolution(getButtonScreen())
drawButtons()
os.sleep(5)