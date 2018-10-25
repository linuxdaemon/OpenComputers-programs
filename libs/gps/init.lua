-- Modifed from https://github.com/OpenPrograms/ds84182-Programs/blob/master/gps/libgps.lua
-- Which is based on https://github.com/dan200/ComputerCraft/blob/master/src/main/resources/assets/computercraft/lua/rom/apis/gps.lua
local gps = {
  port=8192,
  header="GPS"
}

local vector = require "vector2"
local component = require "component"
local event = require "event"

local function trilaterate( A, B, C )
  local a2b = B.position - A.position
  local a2c = C.position - A.position

  if math.abs( a2b:normalize():dot( a2c:normalize() ) ) > 0.999 then
    return nil
  end

  local d = a2b:length()
  local ex = a2b:normalize( )
  local i = ex:dot( a2c )
  local ey = (a2c - (ex * i)):normalize()
  local j = ey:dot( a2c )
  local ez = ex:cross( ey )

  local r1 = A.distance
  local r2 = B.distance
  local r3 = C.distance

  local x = (r1*r1 - r2*r2 + d*d) / (2*d)
  local y = (r1*r1 - r3*r3 - x*x + (x-i)*(x-i) + j*j) / (2*j)

  local result = A.position + (ex * x) + (ey * y)

  local zSquared = r1*r1 - x*x - y*y
  if zSquared > 0 then
    local z = math.sqrt( zSquared )
    local result1 = result + (ez * z)
    local result2 = result - (ez * z)

    local rounded1, rounded2 = result1:round( 0.01 ), result2:round( 0.01 )
    if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
      return rounded1, rounded2
    else
      return rounded1
    end
  end
  return result:round( 0.01 )
end

local function narrow( p1, p2, fix )
  local dist1 = math.abs( (p1 - fix.position):length() - fix.distance )
  local dist2 = math.abs( (p2 - fix.position):length() - fix.distance )

  if math.abs(dist1 - dist2) < 0.01 then
    return p1, p2
  elseif dist1 < dist2 then
    return p1:round( 0.01 )
  else
    return p2:round( 0.01 )
  end
end

function gps.locate( timeout, modem, debug )
  modem = modem or component.modem
  timeout = timeout or 2

  if modem == nil then
    if debug then
      print( "No wireless modem attached" )
    end
    return nil
  end

  if debug then
    print( "Finding position..." )
  end

  local opened_port = false
  if not modem.isOpen(gps.port) then
    modem.open(gps.port)
    opened_port = true
  end

  -- Wait for the updates
  local fixes = {}
  local received_from = {}
  local pos1, pos2 = nil, nil
  while true do
    local e = {event.pull(timeout, "modem_message", modem.address, nil, gps.port, nil, gps.header)}
    if not e[1] then
      if debug then
        print("timeout reached")
      end
      break
    end
    -- We received a message from a modem
    local from = e[3]
    local distance = e[5]
    if not from then
      error("nil from address")
    end
    local packet = {table.unpack(e, 6)}
    -- ignore modems we've already seen
    if not received_from[from] then
      received_from[from] = true
      -- Ignore the packet header as we match it in the event.pull call already
      local message = {table.unpack(packet,2)}
      -- Received the correct message from the correct modem: use it to determine position
      if #message == 3 then
        local fix = { position = vector.new( message[1], message[2], message[3] ), distance = distance }
        if debug then
          print(string.format("%s meters from %s", fix.distance, fix.position))
        end
        if fix.distance == 0 then
          pos1, pos2 = fix.position, nil
        else
          table.insert( fixes, fix )
          if #fixes >= 3 then
            if not pos1 then
              pos1, pos2 = trilaterate( fixes[1], fixes[2], fixes[#fixes] )
            else
              pos1, pos2 = narrow( pos1, pos2, fixes[#fixes] )
            end
          end
        end
        if pos1 and not pos2 then
          break
        end
      end
    end
  end

  if opened_port then
    modem.close(gps.port)
  end

  -- Return the response
  if pos1 and pos2 then
    if debug then
      print( "Ambiguous position" )
      print(string.format("Could be %s or %s", pos1, pos2))
    end
    return nil
  elseif pos1 then
    if debug then
      print(string.format("Position is %s", pos1))
    end
    return pos1.x, pos1.y, pos1.z
  else
    if debug then
      print( "Could not determine position" )
    end
    return nil
  end
end

function gps.host(x, y, z, modem, port, interval)
  -- Find a modem
  modem = modem or component.modem
  port = port or gps.port
  interval = interval or 1

  if modem == nil then
    print( "No wireless modems found. One required." )
    return
  end

  -- Open a channel
  print("Opening port on modem " .. modem.address)
  local openedChannel = false
  if not modem.isOpen(port) then
    modem.open(port)
    openedChannel = true
  end

  -- Determine position
  if not x then
    -- Position is to be determined using locate
    x,y,z = gps.locate(nil, modem, true)
    if not x then
      print( "Could not locate, set position manually" )
      if openedChannel then
        print( "Closing GPS port" )
        modem.close(port)
      end
      return
    end
  end

  -- Serve requests indefinately
  while true do
    -- broadcast
    modem.broadcast(port, gps.header, x, y, z)
    -- sleep
    os.sleep(interval)
  end

  --print( "Closing channel" )
  --modem.close( port )
end

return gps
