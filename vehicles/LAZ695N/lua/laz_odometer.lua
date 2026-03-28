-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local distanceTotalm = 0
local distanceTotalkm = 0
local distanceFromLastSave = 0

-- Streamliner's/53_herbie_53's Trip-Saving LUA
local function loadCurrentTrip()
	local path = "vehicles/LAZ695N/odometer.txt"
	-- create new if not existent
	local check_file = io.open(path, "r" )
	if check_file == nil then
		local file_ = io.open(path, "w")
		io.close(file_)
	end

	-- get data
	local file = io.open(path, "r")
	io.input(file)
	local value = io.read()
	if value == nil then
	local randomValue = math.random() + math.random() * 100000
		distanceTotalm = 100000 * 1000 + randomValue
		--print('failed to read value')
	else
		distanceTotalm = value * 1000
		--print('loaded up saved value')
	end
	io.close(file)
end


local function writeCurrentTrip(value)
	local file = io.open("vehicles/LAZ695N/odometer.txt", "w")
	io.output(file)
	io.write(value)
	io.close(file)
	distanceFromLastSave = 0
	--print("balls")
end


local function updateGFX(dt)
    if playerInfo.anyPlayerSeated then
	distanceTotalm = distanceTotalm + electrics.values.wheelspeed * dt
	
	distanceFromLastSave = distanceFromLastSave + electrics.values.wheelspeed * dt 
	
	
	distanceTotalkm = distanceTotalm / 1000
	electrics.values.distanceTotalm = distanceTotalm
	
	if distanceFromLastSave >= 50 then writeCurrentTrip(distanceTotalkm) end
	

	electrics.values['odo'] = distanceTotalm * 0.36 % 360
	electrics.values['odokm'] = (math.floor(distanceTotalm/1000) + math.max((((distanceTotalm % 1000)-900)/100),0)) * 36 % 360
	electrics.values['odo10km'] = (math.floor(distanceTotalm/10000) + math.max((((distanceTotalm % 10000)-9900)/100),0)) * 36 % 360
	electrics.values['odo100km'] = (math.floor(distanceTotalm/100000) + math.max((((distanceTotalm % 100000)-99900)/100),0)) * 36 % 360
	electrics.values['odo1000km'] = (math.floor(distanceTotalm/1000000) + math.max((((distanceTotalm % 1000000)-999900)/100),0)) * 36 % 360
	electrics.values['odo10000k'] = (math.floor(distanceTotalm/10000000) + math.max((((distanceTotalm % 10000000)-9999900)/100),0)) * 36 % 360
	electrics.values['odo100000k'] = (math.floor(distanceTotalm/100000000) + math.max((((distanceTotalm % 100000000)-99999000)/100),0)) * 36 % 360
end
end

local function onInit()
	loadCurrentTrip()
end


-- public interface
M.onInit = onInit
M.onReset = reset
M.updateGFX = updateGFX

return M