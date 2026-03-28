-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"
M.relevantDevice = nil

local min = math.min


local nodeID = nil

local fanSound = nil

local activePlayed = nil
local deactivePlayed = nil

local function initSounds()
	fanSound = obj:createSFXSource("vehicles/LAZ695N/sounds/fan.wav", 'AudioDefaultLoop3D', "", 1)

	obj:stopSFX(fanSound)
    obj:cutSFX(fanSound)
end

local function updateGFX(dt)
	if electrics.values.rpm>0 then
		obj:playSFX(fanSound)
		obj:setVolumePitch(fanSound, min(0.5,(-0.0008*(0-electrics.values.rpm))), (electrics.values.rpm*0.0007))
	elseif electrics.values.rpm<390 then
		obj:stopSFX(fanSound)
	end
end

local function reset()
    obj:stopSFX(fanSound)
    obj:cutSFX(fanSound)
end

local function init(jbeamData)
	if jbeamData.soundNode_nodes and type(jbeamData.soundNode_nodes) == "table" and type(jbeamData.soundNode_nodes[1]) == "number" then
		nodeID = jbeamData.soundNode_nodes[1]
	else
		soundNode = 0
	end
end

M.initSounds = initSounds
M.updateGFX = updateGFX
M.reset = reset
M.init = init

return M
