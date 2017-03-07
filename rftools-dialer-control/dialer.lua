local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local button = require("button")

local dialer = component.rftools_dialing_device
local gpu = component.gpu

local receivers = {}

local caughtInterrupt = false
local startingScreen = gpu.getScreen()
local btnScreen = nil
local bh = nil

local function log(line)
  gpu.bind(startingScreen)
  print(line)
  if btnScreen then gpu.bind(btnScreen.address) end
end

local function getTx()
  return dialer.getTransmitters()[1]
end

local function getButtonScreen()
  for screen in component.list('screen', true) do
    if #component.invoke(screen, "getKeyboards") == 0 then
      btnScreen = component.proxy(screen)
      return btnScreen
    end
  end
end

local function alignResolution()
  local sizeRatio = 2
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
  for _,rx in ipairs(dialer.getReceivers()) do
    if rx.dimension == 0 then
      receivers[#receivers + 1] = rx
    end
  end
end

local function interrupt()
  dialer.interrupt(getTx())
end

local function atExit()
  if bh and bh:running() then bh:stop() end
  gpu.bind(btnScreen.address)
  term.clear()
  gpu.bind(startingScreen)
end

local function dial(receiver)
  local res, err = dialer.dial(getTx().position, receiver.position, receiver.dimension, false)
  if not res then
    atExit()
    error(err)
  end
end

local function dialCBGen(rx)
  return function(btn)
    bh:flashButton(gpu, btn, 0.1, 0xffffff, 0x0000ff, 0xffffff, 0xa0a0a0)
    dial(rx)
  end
end

local reload -- forward declaration for buttons

local function drawButtons()
  log("Drawing buttons")
  alignResolution()
  term.clear()
  local longest = 16
  for _,rx in ipairs(receivers) do
    if rx.name:len() > longest then longest = rx.name:len() end
  end
  if bh then
    bh:clear()
  end
  bh = bh or button.ButtonHandler()

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
  bh:register(button.Button(1, scHeight-rowHeight, columnWidth-2, rowHeight-2, reload, "Reload"))
  bh:register(button.Button(scWidth - columnWidth, scHeight - rowHeight, columnWidth-2, rowHeight-2, interrupt, "Interrupt"))
  bh:drawAll(gpu)
end

local function reload()
  loadRx()
  drawButtons()
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

local function main()
  getButtonScreen()
  gpu.bind(btnScreen.address)
  clearScreens()
  loadRx()
  drawButtons()
  mainLoop()
end

main()
