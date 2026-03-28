-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = "bus"
M.type = "auxilliary"
M.relevantDevice = nil
M.defaultOrder = 1000

M.doorsOpen = false
M.isKneeling = false
M.isSupensionRaised = false

local doorController = nil
local airbagController = nil

local hasSafetyInterlock = false
local wheelspeed = 0
local doorLever = 0
local doorLeverSmoother = nil

local hasRegisteredQuickAccess = false

local htmlTexture = require("htmlTexture")
local destScreenName = nil
local destHtmlPath = nil
local NSdisplayScreenName = nil
local NSHtmlPath = nil

local currentLine = {}
local timer = 0
local curWaypoint = 1
local lastApproach = -1

local function toggleDoors()
  if wheelspeed > 2 and hasSafetyInterlock then
    return
  end

  if doorLever > 0 then
    doorLever = 0
  else
    doorLever = 1
  end

  local doors = controller.getControllerSafe('doors')
  if doors then
    doors.toggleBeamMinMax({'frontDoors', 'rearDoors'})
  else
    M.doorsOpen = doorLever > 0
    electrics.values.dooropen = M.doorsOpen and 1 or 0
  end
end

local function kneel()
  if wheelspeed >= 2 and hasSafetyInterlock then
    return
  end

  local airbags = controller.getControllerSafe('airbags')
  if airbags then
    airbags.setBeamPressureLevel({'rightAxle'}, 'kneelPressure')
  else
    M.isKneeling = true
    electrics.values.kneel = 1
  end
end

local function toggleKneel()
  local airbags = controller.getControllerSafe('airbags')
  if M.isKneeling then
    if airbags then
      airbags.setBeamDefault({'rightAxle', 'leftAxle'})
    else
      M.isKneeling = false
      electrics.values.kneel = 0
    end
  else
    kneel()
  end
end

local function geCallback(event,data)
  local pos = obj:getPosition()
  local rot = obj:getRotation()

  data.event = event
  --transform userdata into table
  data.pos = vec3(pos):toTable()
  data.rot = quat(rot):toTable()
  obj:queueGameEngineLua("if core_busRouteManager then core_busRouteManager.onBusUpdate("..dumps(data)..") end")
end

local function updateGFX(dt)
  if doorController then
    local frontDoorOpen = doorController.isBeamGroupAtPressureLevel("frontDoors","minPressure")
    local rearDoorOpen = doorController.isBeamGroupAtPressureLevel("rearDoors","minPressure")
    M.doorsOpen = frontDoorOpen or rearDoorOpen
  end

  if airbagController then
    M.isKneeling = airbagController.isBeamGroupAtPressureLevel("rightAxle","kneelPressure")
    M.isSupensionRaised = airbagController.isBeamGroupAtPressureLevel("rightAxle","maxPressure")
  end

  wheelspeed = electrics.values.wheelspeed or 0

  if (M.doorsOpen or M.isKneeling) and wheelspeed < 2 and hasSafetyInterlock then
    electrics.values.throttle = 0
    electrics.values.brake = 1
  end

  electrics.values.dooropen = M.doorsOpen and 1 or 0
  electrics.values.kneel = M.isKneeling and 1 or 0
  electrics.values.rideheight = M.isSupensionRaised and 1 or 0
  electrics.values.doorLever = doorLeverSmoother:getUncapped(doorLever, dt)

  timer = timer + dt
  if timer > 0.5 then
    timer = timer % 0.5
    if currentLine.tasklist and currentLine.tasklist[curWaypoint] then
      --log("E",logTag,"pos ="..dumps(currentLine.tasklist[cur][3]))
      local dist = vec3(currentLine.tasklist[curWaypoint][3] ):distance(vec3(obj:getPosition()))
      -- log("E",logTag,"dist ="..tostring(dist))
      if dist < 75 and curWaypoint ~= lastApproach then
        controller.onGameplayEvent("bus_onApproachStop", {triggerName=currentLine.tasklist[curWaypoint][1]})
        lastApproach = curWaypoint
      end
    end
  end
end

local function reset()
  M.doorsOpen = false
  M.isKneeling = false
  M.isSupensionRaised = false
  doorLever = 0
  electrics.values.dooropen = 0
  electrics.values.doorlever = 0
  electrics.values.kneel = 0
  electrics.values.rideheight = 0

  timer = 0
  curWaypoint = 1
  lastApproach = -1
end

local function registerQuickAccess()
  if not hasRegisteredQuickAccess and core_quickAccess ~= nil then
    core_quickAccess.addEntry({ level = '/', title = 'Bus', icon="material_directions_bus", ["goto"] = '/bus/'} )
    core_quickAccess.addEntry({ level = '/bus/', generator = function(entries)
          local e = { title = 'ui.radialmenu2.bus.kneel', icon="material_arrow_downward", onSelect = function() toggleKneel() return {'reload'} end }
          if electrics.values.kneel == 1 then e.color = '#ff6600' end
          table.insert(entries, e)

          e = { title = 'ui.radialmenu2.bus.doors', icon="radial_hinges", onSelect = function() toggleDoors() return {'reload'} end }
          if electrics.values.dooropen == 1 then e.color = '#ff6600' end
          table.insert(entries, e)
        end})

    hasRegisteredQuickAccess = true
  end
end

local function init(jbeamData)
  hasSafetyInterlock = jbeamData.hasSafetyInterlock or false

  M.doorsOpen = false
  M.isKneeling = false
  M.isSupensionRaised = false
  electrics.values.dooropen = 0
  electrics.values.doorlever = 0
  electrics.values.kneel = 0
  electrics.values.rideheight = 0

  doorLeverSmoother = newTemporalSmoothing(2,2)
  doorLever = 0

  registerQuickAccess()

  if jbeamData.nextStopNode and v.data[jbeamData.nextStopNode] then
    local nsData = v.data[jbeamData.nextStopNode]
    NSdisplayScreenName = nsData.NSmaterialName
    NSHtmlPath = nsData.NShtmlPath
    local NSwidth = nsData.NStextureWidth or 512
    local NSheight = nsData.NStextureHeight or 384

    if NSHtmlPath and NSdisplayScreenName then
      htmlTexture.create(NSdisplayScreenName, NSHtmlPath, NSwidth, NSheight, 15, 'automatic')
    else
      log("E", logTag, "Got no html or material name path for NextStop, no HTML texture created!!!...")
    end
  end

  if jbeamData.destinationSignNode and v.data[jbeamData.destinationSignNode] then
    local destData = v.data[jbeamData.destinationSignNode]
    destScreenName = destData.destMaterialName or destScreenName
    destHtmlPath = destData.destHtmlPath
    local destWidth = destData.destTextureWidth or 256
    local destHeight = destData.destTextureHeight or 16
    local destText = destData.destText or ""
    local destRoute = destData.destRoute or ""

    if destHtmlPath and destScreenName then
      htmlTexture.create(destScreenName, destHtmlPath, destWidth, destHeight, 4, 'automatic')
      htmlTexture.call(destScreenName, "update", {direction = destText, routeID = destRoute} )
    else
      log("E", logTag, "Got no html path or material name for destination, no HTML texture created!!!...")
    end
  end
end

local function initSecondStage()
  doorController = controller.getController("doors")
  airbagController = controller.getController("airbags")
end

local function recalculateStopList()
  local sl = {}
  for i = curWaypoint, #currentLine.tasklist, 1 do
    table.insert(sl, currentLine.tasklist[i][2])
  end
  return sl
end

--duplicate code at scenario/busdriver.lua:62
local function isTriggerOnBusLine(tasks,tname)
  for _,v in pairs(tasks) do
    if v[1] == tname then return true end
  end
  return false
end

local function uiSetLine(routeID, variance)
  obj:queueGameEngineLua("if core_busRouteManager then core_busRouteManager.setLine("..tostring(obj:getID())..","..dumps(routeID)..","..dumps(variance)..") end")
end

local function onGameplayEvent(eventName, eventData)
  if eventName == "bus_onRouteChange" then
    if destScreenName then
      htmlTexture.call(destScreenName, "update", eventData)
    end
    if NSdisplayScreenName then
      htmlTexture.call(NSdisplayScreenName, "updateDisplay", eventData)
    end
    guihooks.trigger('BusDisplayUpdate', eventData)

  elseif eventName == "bus_onDepartedStop" then
    if not currentLine.tasklist or #currentLine.tasklist == 0 then
      log("E",logTag,"No tasklist!")
      return
    end
    if not isTriggerOnBusLine(currentLine.tasklist, eventData.triggerName) then return end

    --fix spawning the bus in last busstop trigger, you still cannot go through, only exit once
    if currentLine.tasklist[#currentLine.tasklist][1] == eventData.triggerName and curWaypoint<#currentLine.tasklist  then
      return
    end

    for i=1, #currentLine.tasklist, 1 do
      if currentLine.tasklist[i][1] == eventData.triggerName then curWaypoint=i;break end
    end
    curWaypoint = curWaypoint + 1

    local stopList = recalculateStopList()

    if NSdisplayScreenName then
      htmlTexture.call(NSdisplayScreenName, "updateDisplay", stopList)
    end
    guihooks.trigger('BusDisplayUpdate', stopList)

    geCallback("onDepartedStop",eventData)

  elseif eventName == "bus_onAtStop" then
    if not currentLine.tasklist or #currentLine.tasklist == 0 then
      log("E",logTag,"No tasklist!")
      return
    end
    if not isTriggerOnBusLine(currentLine.tasklist, eventData.triggerName) then return end

    for i = 1, #currentLine.tasklist, 1 do
      if currentLine.tasklist[i][1] == eventData.triggerName then curWaypoint = i; break end
    end

    geCallback("onAtStop", eventData)

  elseif eventName == "bus_onApproachStop" then
    -- guihooks.trigger('Message', {ttl = 5, msg = 'onApproachStop', icon = 'directions_bus'})

    for i = 1, #currentLine.tasklist, 1 do
      if currentLine.tasklist[i][1] == eventData.triggerName then curWaypoint = i; break end
    end

    geCallback("onApproachStop", eventData)

  elseif eventName == "bus_setLineInfo" then
    -- log("I",logTag..".setLineInfo","eventData received in lua veh ="..dumps(eventData))
    reset()
    currentLine = eventData
    controller.onGameplayEvent("bus_onRouteChange", currentLine)
    -- if currentLine.tasklist[1] then
    --   controller.onGameplayEvent("bus_onAtStop",{triggerName=currentLine.tasklist[1][1]})
    -- end

  elseif eventName == "bus_onTriggerTick" then
    eventData.speed = electrics.values.wheelspeed * 3.6
    eventData.bus_dooropen = M.doorsOpen
    eventData.bus_kneel = M.isKneeling
    geCallback("onTriggerTick",eventData)
  end
end

M.init = init
M.initSecondStage = initSecondStage
M.reset = reset
M.updateGFX = updateGFX
M.onGameplayEvent = onGameplayEvent

M.toggleDoors = toggleDoors
M.toggleKneel = toggleKneel

M.uiSetLine = uiSetLine

return M
