-- Exercise real visual-integration functions with mocked FiveM/ox_lib natives.
local vector={}
vector.__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
vector.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
vec3=function(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
local function close(a,b) return math.abs(a-b)<.00001 end
Lang={wash={}};cache={ped=1,serverId=11,playerId=0}
dofile('crimson-mechanic/config.lua')
assert(Config.Wash.tools.gun.model=='crimson_pressure_washer' and not Config.Wash.tools.gun.hidden)
local threads={};CreateThread=function(fn) threads[#threads+1]=fn end
AddStateBagChangeHandler=function() end
joaat=function(name) return name end
local clock=0;GetGameTimer=function() return clock end
Wait=function(ms) clock=clock+ms end
local positions={[1]=vec3(0,0,0),[2]=vec3(20,0,0)}
local entities={[1]=true,[2]=true};local counter=50
local created,deleted,ropeDeleted=0,0,0
local state={}
Player=function(id) return {state={crimsonWash=state[id]}} end
GetEntityCoords=function(e) return positions[e] end
DoesEntityExist=function(e) return entities[e]==true end
GetOffsetFromEntityInWorldCoords=function(e,x,y,z) return positions[e]+vec3(x,y,z) end
GetOffsetFromEntityGivenWorldCoords=function(e,x,y,z) return vec3(x,y,z)-positions[e] end
GetPedBoneCoords=function(e) return positions[e]+vec3(0,.1,0) end
GetPedBoneIndex=function() return 1 end
GetEntityHeading=function() return 0 end
lib={requestModel=function() end,requestNamedPtfxAsset=function() end}
HasModelLoaded=function() return true end
HasNamedPtfxAssetLoaded=function() return true end
SetModelAsNoLongerNeeded=function() end
CreateObject=function(_,x,y,z) counter=counter+1;entities[counter]=true;positions[counter]=vec3(x,y,z);created=created+1;return counter end
DeleteEntity=function(e) assert(entities[e]);entities[e]=false;deleted=deleted+1 end
SetEntityCollision=function() end
SetEntityAlpha=function() end
FreezeEntityPosition=function() end
AttachEntityToEntity=function() end
RopeLoadTextures=function() end
RopeAreTexturesLoaded=function() return true end
local rope=0;local ropes={}
AddRope=function() rope=rope+1;ropes[rope]=true;return rope end
DoesRopeExist=function(id) return ropes[id]==true end
DeleteRope=function(id) assert(ropes[id]);ropes[id]=false;ropeDeleted=ropeDeleted+1 end
local lastTip
AttachEntitiesToRope=function(_,_,_,x,y,z) lastTip=vec3(x,y,z) end
UseParticleFxAssetNextCall=function() end
RemoveNamedPtfxAsset=function() end
local localFx,remoteFx,fxCreated
fxCreated=0
StartParticleFxLoopedOnEntity=function(_,ped,x,y,z) localFx={ped=ped,pos=vec3(x,y,z)};fxCreated=fxCreated+1;return fxCreated end
StartParticleFxLoopedAtCoord=function(_,x,y,z) remoteFx=vec3(x,y,z);fxCreated=fxCreated+1;return fxCreated end
StopParticleFxLooped=function() end
SetParticleFxLoopedOffsets=function() end
local f=assert(io.open('crimson-mechanic/client/wash.lua'));local src=f:read('*a');f:close()
src=src:gsub('`[^`]+`','0')
src=src:sub(1,assert(src:find('%-%- Dirt level while being washed'))-1)
local api=assert(load(src..'\nreturn {refresh=refreshVisual,stop=stopVisual,nozzle=nozzleOffset,jet=setJet,visuals=visuals,destroy=destroyVisual}'))()
local function data(id,tool) return {id=id,tool=tool or 'gun',ax=10,ay=0,az=2,len=12} end
local function build(serverId,ped,d)
 state[serverId]=d;api.refresh(serverId,d,ped);threads[#threads]()
 return api.visuals[serverId] and api.visuals[serverId].visual
end
local own=assert(build(11,1,data(1)))
assert(own.toolKey=='gun' and own.rope and own.anchor,'gun and dynamic hose must be created')
assert(close(lastTip.x,-.07) and close(lastTip.z,-.18),'hose must attach to model connector')
local n=api.nozzle(1);assert(close(n.x,.990) and close(n.z,.041),'own nozzle must originate at model tip')
api.jet(own,'water',0,0);assert(close(localFx.pos.x,.990),'local particle must use model tip')
local remote=assert(build(22,2,data(2)))
api.jet(remote,'foam',0,0);assert(close(remoteFx.x,20.990),'remote particle must use world-space model tip')
local r0=ropeDeleted
local sponge=assert(build(11,1,data(1,'sponge')))
assert(not sponge.rope and ropeDeleted==r0+1,'sponge transition must remove gun hose')
local fallback=api.nozzle(1);assert(close(fallback.y,.15),'sponge must retain original hand-offset fallback')
-- Cancelling while the model request yields must never create an orphan prop.
api.stop(11);local c0=created
lib.requestModel=function() coroutine.yield() end
state[11]=data(3);api.refresh(11,state[11],1)
local pending=coroutine.create(threads[#threads]);assert(coroutine.resume(pending));api.stop(11);assert(coroutine.resume(pending));assert(created==c0)
lib.requestModel=function() end
-- Cancelling after prop creation, during rope setup, must destroy partial props.
Wait=function(ms) clock=clock+ms;api.stop(11) end
build(11,1,data(4));assert(not api.visuals[11]);assert(created-deleted==2,'only remote gun and anchor may remain')
Wait=function(ms) clock=clock+ms end
-- A cancelled effect load must not spawn particles on a retired visual.
local v=assert(build(11,1,data(5)));local fx0=fxCreated
lib.requestNamedPtfxAsset=function() api.stop(11) end
api.jet(v,'water',0,0);assert(fxCreated==fx0)
api.stop(22);local d0=deleted;api.destroy(v);assert(deleted==d0,'cleanup must be idempotent')
assert(created==deleted,'all test-created props must be removed')
print('PASS: custom model, hose connector, local/remote muzzle, sponge transition, cancelled model/rope/effect loads, no leaked props')
