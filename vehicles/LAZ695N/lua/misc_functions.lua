local M = {}

local engtime = 0
local engtimer = 0
local particleAmount = 0
local ignkeySmoother = newExponentialSmoothing(6)
local fuelgaugeSmoother = newExponentialSmoothing(192)
local tempgaugeSmoother = newExponentialSmoothing(256)
local oilPressureSmoother = newExponentialSmoothing(24)
local engine = nil
local rpmToAV = 0.104719755
local originalIdlerpm = 500 * rpmToAV
local min = math.min
local max = math.max
local htmlTexture = require("htmlTexture")
local OilGrade = 15000

local function init()
   electrics.values.shiftlight = 0
   electrics.values.choke_change = 0
   electrics.values.choke = 0
    electrics.values['clockh'] = 0
    electrics.values['clockmin'] = 0
	electrics.values['clocksec'] = 0
	electrics.values.afr = 15
    engine = powertrain.getDevice("mainEngine")
	
    obj:queueGameEngineLua("extensions.loadModule('ui/uinavi')")
	htmlTexture.create("@sats_afr", "local://local/vehicles/LAZ695N/afr.html", 480, 280, 2, 'automatic')
    if electrics.values.turboBoost == nil
    then electrics.values.turboBoost = 0 
end	
rfrsh = 0
end

local function reset()
  engine.idleAV = originalIdlerpm
  electrics.values.fuelgauge = electrics.values.fuel
  electrics.values.AFRON = 1
  onInit()
end

function math.Clamp(val, lower, upper)
    return math.max(lower, math.min(upper, val))
end

local function updateGFX(dt)
   

  

	 
   --fanbelts and cambelt etc etc
   
   if electrics.values.rpm > 100 then electrics.values.beltuberslow = 0.5 else electrics.values.beltuberslow = 0 end
   if electrics.values.rpm > 2300 then electrics.values.beltslow = 1 else electrics.values.beltslow = 0 end
   if electrics.values.rpm > 3000 then electrics.values.beltmid = 1 else electrics.values.beltmid = 0 end
   --timing chain
   if electrics.values.rpm > 100 then electrics.values.chainuberslow = 0.5 else electrics.values.chainuberslow = 0 end
   if electrics.values.rpm > 1300 then electrics.values.chainslow = 1 else electrics.values.chainslow = 0 end
   if electrics.values.rpm > 3000 then electrics.values.chainmid = 1 else electrics.values.chainmid = 0 end
   
   --ignition keyswitch logic
   
   electrics.values.ignkey = 0 + engine.ignitionCoef + engine.starterEngagedCoef
  
    electrics.values.ignkey = ignkeySmoother:get(electrics.values['ignkey'])
	
    if engine.starterEngagedCoef > 0 then
	
	electrics.values.fuelgauge = electrics.values.fuel * (electrics.values.rpmTacho / 700) * electrics.values.ignkey
	electrics.values.tempgauge = electrics.values.watertemp * (electrics.values.rpmTacho / 700)
	else 
	electrics.values.fuelgauge = electrics.values.fuel * engine.ignitionCoef 
	electrics.values.tempgauge = electrics.values.watertemp * engine.ignitionCoef end
	
	electrics.values.fuelgauge = fuelgaugeSmoother:get(electrics.values['fuelgauge'])
	electrics.values.tempgauge = max(tempgaugeSmoother:get(electrics.values['tempgauge']),  30)
	
   --shift light which should probably be deprecated to new lua thing
   if electrics.values.rpm > engine.tempRevLimiterAV * 0.8 then electrics.values.shiftwarn = 1 else electrics.values.shiftwarn = 0 end
   
   if electrics.values.rpmTacho < 500 and electrics.values.ignkey > 1 then
   electrics.values.chargewarn = 1 else electrics.values.chargewarn = 0  end
	
	
	--oil pressure "simulation"
   
     local oilMath1 = 200 - electrics.values.oiltemp
	 local oilMath2 = electrics.values.rpmTacho / OilGrade
	 local oilMath3 = oilMath1 * oilMath2
	 local oilMath4 = oilMath3 / 120
	 local oilMath5 = oilMath4 + 1.1
	 local oilMath6 =  math.min(engine.thermals.debugData.engineThermalData.oilMass / 0.87, 3)
	 
     electrics.values.oilPressure = oilMath5 * oilMath6 * (math.Clamp(electrics.values.rpmTacho, 0, engine.idleAV / 0.104719755) / (engine.idleAV/ 0.104719755))  / engine.wearFrictionCoef * engine.thermals.debugData.engineThermalData.oilLubricationCoef
	 electrics.values.oilPressure = oilPressureSmoother:get(electrics.values['oilPressure'])
 
	if electrics.values.oilPressure < 1.5 and engine.ignitionCoef > 0 then electrics.values.oilwarn = 1 else electrics.values.oilwarn = 0 end

	
 --Coolant pressure 
 
 electrics.values.waterpress = electrics.values.watertemp / 5.5 - 6.2 + electrics.values.rpmTacho / 10000
 if electrics.values.waterpress < 0 then electrics.values.waterpress = 0.0001 else end
 
	--Clock
    local time = os.date("*t", os.time())
    local hour = time.hour % 12
    electrics.values['clockh'] = hour*30
    electrics.values['clockmin'] = time.min*6
    electrics.values['clocksec'] = time.sec*6	

	--AFR crap
	if engine.ignitionCoef >  0.8
	then electrics.values.AFRON = 1 
	else electrics.values.AFRON = 0
	end
	
	if electrics.values.rpm > 840 and electrics.values.ignkey > 0 then
	afrrandom = 0.98 + math.random() * (1.0 - 0.98)
	afrcalc = 18 * afrrandom - (engine.starterEngagedCoef * 3) - engine.sustainedAfterFireCoef - (electrics.values.engineLoad * engine.instantAfterFireCoef * 2.5) + (electrics.values.rpmTacho / 9000 ) + (electrics.values.turboBoost / 7.25) 
	else
	afrcalc = 20
	end
	
	if afrcalc > 18 then
	afrstring = "LEAN"
	end
	
	if afrcalc < 8 then
	afrstring = "RICH"
	end
	
	if afrcalc > 8 and afrcalc < 18 then
	afrmath = math.floor(afrcalc * 10^1) / 10^1
	
    afrstring = tostring(afrmath)
    end
	
	rfrsh = rfrsh + 1 
	if rfrsh > 64 then
	htmlTexture.call("@sats_afr", "updateAFR", afrstring)
	rfrsh = rfrsh * 0
	electrics.values.afr = afrcalc
	end
end



M.onInit = init
M.onReset = init
M.updateGFX = updateGFX

return M