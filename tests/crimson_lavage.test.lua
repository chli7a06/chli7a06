-- Resource lifecycle tests with mocked FiveM natives; not live physics validation.
local vector={}
vector.__sub=function(a,b) return setmetatable({x=a.x-b.x},vector) end
vector.__len=function(a) return math.abs(a.x) end
local function v(x,y,z) return setmetatable({x=x,y=y or 0,z=z or 0},vector) end
local threads,commands,events,exported={},{},{},{}
CreateThread=function(fn) threads[#threads+1]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
AddEventHandler=function(name,fn) events[name]=fn end
exports=function(name,fn) exported[name]=fn end
local clock=0
GetGameTimer=function() return clock end
GetCurrentResourceName=function() return 'crimson_lavage' end
local alive={[1]=true,[2]=true}
local positions={[1]=v(0),[2]=v(2)}
local dead,inVehicle,modelValid,loaded,ropeAvailable=false,false,true,true,true
local ropeLive,gunCounter,created,destroyed,ropeDestroyed=false,10,0,0,0
local pool={2}
PlayerPedId=function() return 1 end
DoesEntityExist=function(entity) return alive[entity]==true end
IsEntityDead=function() return dead end
IsPedInAnyVehicle=function() return inVehicle end
GetGamePool=function() return pool end
GetEntityCoords=function(entity) return positions[entity] end
GetHashKey=function() return 999 end
IsModelInCdimage=function() return modelValid end
IsModelValid=IsModelInCdimage
RequestModel=function() end
HasModelLoaded=function() return loaded end
SetModelAsNoLongerNeeded=function() end
RopeLoadTextures=function() end
RopeAreTexturesLoaded=function() return true end
BeginTextCommandThefeedPost=function() end
AddTextComponentSubstringPlayerName=function() end
EndTextCommandThefeedPostTicker=function() end
CreateObjectNoOffset=function()
 gunCounter=gunCounter+1;created=created+1;alive[gunCounter]=true;positions[gunCounter]=v(0);return gunCounter
end
DeleteEntity=function(entity) assert(alive[entity]);alive[entity]=false;destroyed=destroyed+1 end
SetEntityAsMissionEntity=function() end
SetEntityCollision=function() end
GetPedBoneIndex=function() return 1 end
AttachEntityToEntity=function() end
GetEntityModel=function() return 1 end
GetModelDimensions=function() return v(-1,-2,-.5),v(1,2,1) end
GetOffsetFromEntityInWorldCoords=function(entity,x) return v(positions[entity].x+x) end
AddRope=function() ropeLive=ropeAvailable;return -42 end
DoesRopeExist=function(id) return id==-42 and ropeLive end
DeleteRope=function(id) assert(id==-42 and ropeLive);ropeLive=false;ropeDestroyed=ropeDestroyed+1 end
AttachEntitiesToRope=function() end
RopeForceLength=function(_,length) assert(length<=12 and length>=.5) end
StopAnimTask=function() end
Wait=function() clock=clock+100 end
dofile('crimson_lavage/config.lua');Config.Animation.Enabled=false
dofile('crimson_lavage/client.lua')
local function equip()
 commands.lavage();threads[#threads]()
end
equip();assert(created==1 and ropeLive and alive[gunCounter],'equip must create gun and rope')
commands.lavage();assert(destroyed==1 and ropeDestroyed==1,'toggle off must remove both')
exported.StopWasher();assert(destroyed==1,'cleanup must be idempotent')
modelValid=false;equip();assert(created==1,'invalid model must not spawn');modelValid=true
pool={};equip();assert(created==1,'missing vehicle must not spawn');pool={2}
ropeAvailable=false;equip();assert(created==2 and destroyed==2,'failed rope must clean gun');ropeAvailable=true
loaded=false
commands.lavage()
Wait=function() clock=clock+100;exported.StopWasher() end
threads[#threads]();assert(created==2,'cancelled model load must not spawn late')
loaded=true;Wait=function() clock=clock+100 end
equip();assert(ropeLive)
-- Execute the maintenance worker through a real coroutine boundary.
Wait=function() coroutine.yield() end
local worker=coroutine.create(threads[1])
assert(coroutine.resume(worker))
dead=true;assert(coroutine.resume(worker));assert(not ropeLive and not alive[gunCounter],'death must clean session')
dead=false;Wait=function() clock=clock+100 end
equip();positions[2]=v(30)
Wait=function() coroutine.yield() end
assert(coroutine.resume(worker));assert(not ropeLive and not alive[gunCounter],'distance limit must clean session')
positions[2]=v(2);Wait=function() clock=clock+100 end
equip();events.onResourceStop('other');assert(ropeLive)
events.onResourceStop('crimson_lavage');assert(not ropeLive and not alive[gunCounter],'resource stop must clean session')
for _,path in ipairs({'crimson_lavage/client.lua','crimson_lavage/config.lua','crimson_lavage/fxmanifest.lua'}) do assert(loadfile(path)) end
print('PASS: equip/unequip, idempotent cleanup, bad model, missing vehicle, rope failure, cancelled load, death, hose limit and resource stop')
