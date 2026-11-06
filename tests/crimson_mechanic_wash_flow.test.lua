-- Exercise the real wash stage: input -> aim -> progress -> replicated spray.
local vector={}
vector.__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
vector.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__mul=function(a,b) return vec3(a.x*b,a.y*b,a.z*b) end
vector.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
vec3=function(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
Lang={wash={zones={front='Front',left='Left',right='Right',rear='Rear'},hud_sub='%s %d/%d'}}
cache={ped=1,serverId=11,playerId=0}
dofile('crimson-mechanic/config.lua')
dofile('crimson-mechanic/client/wash_surface.lua')
local clock, mode, requests, published, percentage=0,'control',0,0,0
GetGameTimer=function() return clock end
Wait=function() clock=clock+100 end
CreateThread=function() end
AddStateBagChangeHandler=function() end
local commands={}
RegisterCommand=function(name,fn) commands[name]=fn end
RegisterKeyMapping=function() end
joaat=function(v) return v end
DoesEntityExist=function() return true end
GetEntityCoords=function() return vec3(0,0,0) end
GetOffsetFromEntityGivenWorldCoords=function(_,x,y,z) return vec3(x,y,z) end
GetOffsetFromEntityInWorldCoords=function(_,x,y,z) return vec3(x,y,z) end
GetPedInVehicleSeat=function() return 0 end
IsEntityDead=function() return false end
DisableControlAction=function() end
IsDisabledControlPressed=function() return false end
IsControlPressed=function(_,control) return mode=='control' and control==257 end
IsDisabledControlJustPressed=function() return false end
GetSelectedPedWeapon=function() return 0 end
ShowHudComponentThisFrame=function() end
GetHeadingFromVector_2d=function() return 0 end
GetEntityHeading=function() return 0 end
GetGameplayCamRot=function() return vec3(0,0,0) end
IsEntityPlayingAnim=function() return true end
TaskPlayAnim=function() end
StopAnimTask=function() end
RemoveAnimDict=function() end
HasNamedPtfxAssetLoaded=function() return false end
RequestNamedPtfxAsset=function() requests=requests+1 end
NetworkGetEntityOwner=function() return 0 end
SetVehicleDirtLevel=function() end
TriggerServerEvent=function() end
lib={requestAnimDict=function() end,requestNamedPtfxAsset=function() error('must not suspend the wash loop') end}
LocalPlayer={state={set=function(_,key,value,replicated)
 assert(key=='crimsonWash' and replicated)
 if value and value.fx then
  assert(value.distance==2 and (value.fx=='water' or value.fx=='foam'))
  assert(value.surface and value.surface.vehicle==99 and value.surface.patches[1].kind==value.fx,'surface coating must be included in replicated wash state')
  published=published+1
 end
end}}
json={encode=function(v) return tostring(v) end}
SendNUIMessage=function(v) if v.action=='wash' then percentage=math.max(percentage,v.data.pct) end end
local file=assert(io.open('crimson-mechanic/client/wash.lua'));local source=file:read('*a');file:close()
source=source:gsub('`[^`]+`','0')
source=source:sub(1,assert(source:find('local function startWash',1,true))-1)
local api=assert(load(source..[[
local physicalAim=aimAt
aimAt=function() return vec3(0,1,0),vec3(0,2,0),9,2,vec3(0,0,1) end
sideOf=function() return ZONES[math.floor(GetGameTimer()/500)%4+1],0 end
visuals[11]={visual={ped=1,tool=2,toolKey='gun'}}
return {physicalAim=physicalAim,run=runStage,input=sprayPressed,active=function(value) washing=value end}
]]))()
local rayOrigin,rayEnd
StartExpensiveSynchronousShapeTestLosProbe=function(x,y,z,tx,ty,tz)
 rayOrigin=vec3(x,y,z);rayEnd=vec3(tx,ty,tz);return 1
end
GetShapeTestResult=function() return 2,1,rayOrigin+(rayEnd-rayOrigin)*.4,vec3(0,0,1),9 end
local axis,hit,entity,distance=api.physicalAim(1)
assert(axis.x>.99 and axis.z<0 and entity==9 and math.abs(distance-2.4)<.0001)
assert(rayOrigin.x==.760 and math.abs(rayOrigin.z-.041)<.0001,'impact ray must start at the real muzzle')
for _,case in ipairs({'control','binding'}) do
 clock,mode,percentage=0,case,0
 api.active(true)
 if case=='binding' then commands['+crimsonWashSpray']() end
 assert(api.input(),'attack variant or mapped LMB must register')
 local ok=api.run({vehicle=9,netId=99,vehicleCoords=vec3(0,0,0),anchor=vec3(0,0,0),length=10,dirt=10,deadline=10000,id=1},
  {tool='gun',fx=case=='control' and 'water' or 'foam',label='Test',zoneTime=400,dirt=.7},1)
 assert(ok and clock<10000 and percentage>0,'stage must progress with particle assets unavailable')
 commands['-crimsonWashSpray']();api.active(false)
end
mode='none';assert(not api.input(),'release must clear the mapped input')
assert(requests>0 and published>0)
print('PASS: real water/foam stages progress and replicate from attack input or mapped LMB while PTFX is unavailable')
