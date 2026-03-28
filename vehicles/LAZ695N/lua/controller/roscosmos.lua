-- This Source Code Form is subject to the terms of GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007
-- If a copy of the license was not distributed with this
-- file, You can obtain one at https://spdx.org/licenses/GPL-3.0.html
-- Copyright (C) 2019  thomatoes50 (Thomas Portassau)

local M = {}
M.type = "auxilliary"
M.relevantDevice = nil
M.defaultOrder = 1100

local vehicleID = obj:getID()

local timer=0

local lastJatoInput = -1

local thrusterCount = 0
local thrusterNodes={}
local thrusterLoops
local playingSound = false
local smokeTick = 0

local meshes = {"priora_jato_shockdiamonds_L", "priora_jato_shockdiamonds_R"}
local fmShock = {}

local function findNode(nodeName)
    for _,n in pairs(v.data.nodes) do
        if n.name == nodeName then
            return n.cid
        end
    end
    return -1
end

local function init(jbeamData)
    electrics.values.thruster_input = 0
    electrics.values.elevator_input = 0
    electrics.values.elevator_up = 0
	electrics.values.elevator_down = 0
    electrics.values.aileron_input = 0

    thrusterNodes={}
    if jbeamData.thrusterRNodes_nodes and #jbeamData.thrusterRNodes_nodes >=2 then
        table.insert(thrusterNodes, {jbeamData.thrusterRNodes_nodes[1], jbeamData.thrusterRNodes_nodes[2]})
    else
        table.insert(thrusterNodes, {findNode(jbeamData.thrusterRNodes[1]), findNode(jbeamData.thrusterRNodes[2])})
    end
    if jbeamData.thrusterLNodes_nodes and #jbeamData.thrusterLNodes_nodes >=2 then
        table.insert(thrusterNodes, {jbeamData.thrusterLNodes_nodes[1], jbeamData.thrusterLNodes_nodes[2]})
    else
        table.insert(thrusterNodes, {findNode(jbeamData.thrusterLNodes[1]), findNode(jbeamData.thrusterLNodes[2])})
    end
    thrusterCount = #thrusterNodes

    dump(thrusterNodes)

    for _, flexbody in pairs(v.data.flexbodies) do
        if (meshes[1] == flexbody.mesh or meshes[2] == flexbody.mesh) and flexbody.fid then
          table.insert(fmShock, obj.ibody:getFlexmesh(flexbody.fid) )
        end
    end
end

local function onReset()

    smokeTick = 0

    for i = 1, thrusterCount, 1 do
        local loop = thrusterLoops[i]
        obj:stopSFX(loop)
    end
    for _,m in pairs(fmShock) do
        obj:setMeshAlpha(m, 0)
    end

    electrics.values.thruster_input = 0
    electrics.values.elevator_input = 0
    electrics.values.elevator_up = 0
    electrics.values.elevator_down = 0
    electrics.values.aileron_input = 0

end

local function updateGFX(dt)

    local jatoInput = math.min(electrics.values.thruster_input or 0, 1)

    -- print("jatoInput="..tostring(jatoInput).."\tlastJatoInput="..tostring(lastJatoInput))

    --if jatoInput ~= lastJatoInput then
        for _,m in pairs(fmShock) do
            obj:setMeshAlpha(m, math.max(electrics.values.thruster_input or 0, 0))
        end
    --end

    electrics.values.elevator_up =  electrics.values.elevator_input > 0 and electrics.values.elevator_input or 0
    electrics.values.elevator_down = electrics.values.elevator_input < 0 and math.abs(electrics.values.elevator_input) or 0

    electrics.values.aileron_R =  electrics.values.aileron_input > 0 and electrics.values.aileron_input or 0
    electrics.values.aileron_L = electrics.values.aileron_input < 0 and math.abs(electrics.values.aileron_input) or 0

    smokeTick= smokeTick + dt * jatoInput * 100
    if smokeTick > 1 then
        for i = 1, thrusterCount, 1 do
            local thruster = thrusterNodes[i]
            obj:addParticleByNodes(thruster[1], thruster[2], 20, 81, 0.01, 1)
        end
        smokeTick = 0
    end

    if playingSound and jatoInput > 0 then
        for i = 1, thrusterCount, 1 do
            local loop = thrusterLoops[i]
            obj:setVolume(loop, jatoInput)
        end
    else
        if jatoInput > 0 and lastJatoInput <= 0 then
            playingSound = true
            for i = 1, thrusterCount, 1 do
                local loop = thrusterLoops[i]
                obj:setVolume(loop, jatoInput)
                obj:playSFX(loop)
            end
        end
      end

    if jatoInput <= 0 and lastJatoInput > 0 then
        playingSound = false
        for i = 1, thrusterCount, 1 do
            local loop = thrusterLoops[i]
            obj:stopSFX(loop)
        end
    end
    lastJatoInput = jatoInput
end

local function initSounds()
    thrusterLoops = {}
    for i = 1, thrusterCount, 1 do
      local thruster = thrusterNodes[i]
      local loop = obj:createSFXSource("event:>Vehicle>Afterfire>04_Rocket", "AudioDefaultLoop3D", "jatoThrusterLoop", thruster[1])
      table.insert(thrusterLoops, loop)
    end
  end


-- public interface
M.init    = init
M.initSounds = initSounds
M.reset   = reset
M.updateGFX = updateGFX

return M
