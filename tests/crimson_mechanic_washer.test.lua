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
Config.Wash.hose.renderer='native' -- Retain fallback coverage before exercising rubber renderer.
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
CreateObjectNoOffset=CreateObject
SetEntityAsMissionEntity=function() end
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
local lastHoseLength
RopeForceLength=function(_,length) lastHoseLength=length end
local lastTip
GetRopeVertexCount=function() return 8 end
PinRopeVertex=function(_,index,x,y,z) if index==0 then lastTip=vec3(x,y,z) end end
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
local api=assert(load(src..'\nreturn {refresh=refreshVisual,stop=stopVisual,nozzle=nozzleOffset,jet=setJet,visuals=visuals,destroy=destroyVisual,updateHose=updateHose,drawHose=drawRubberHose,animation=washAnimation}'))()
local function data(id,tool) return {id=id,tool=tool or 'gun',ax=10,ay=0,az=2,len=12} end
local function build(serverId,ped,d)
 state[serverId]=d;api.refresh(serverId,d,ped);threads[#threads]()
 return api.visuals[serverId] and api.visuals[serverId].visual
end
local own=assert(build(11,1,data(1)))
assert(own.toolKey=='gun' and own.rope and own.anchor,'gun and dynamic hose must be created')
assert(lastHoseLength < 12 and lastHoseLength > 10,'visible hose length must not use the full walking allowance')
local previous=lastHoseLength;positions[own.tool]=vec3(1,0,0);api.updateHose(own);assert(lastHoseLength<previous,'hose must follow changing endpoint distance');positions[own.tool]=vec3(0,0,0);api.updateHose(own)
assert(close(lastTip.x,-.07) and close(lastTip.z,-.18),'hose must attach to model connector')
local n=api.nozzle(1);assert(close(n.x,.760) and close(n.z,.041),'own nozzle must originate at model tip')
api.jet(own,'water',0,0);assert(close(localFx.pos.x,.760),'local particle must use model tip')
local remote=assert(build(22,2,data(2)))
api.jet(remote,'foam',0,0);assert(close(remoteFx.x,20.760),'remote particle must use world-space model tip')
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
-- Smooth black hose must not create a braided native rope or an anchor prop.
Config.Wash.hose.renderer='rubber';lib.requestNamedPtfxAsset=function() end
local ropesBefore=rope;local objectsBefore=created
local rubber=assert(build(11,1,data(6)))
assert(rubber.hoseMesh and not rubber.rope and not rubber.anchor)
assert(created==objectsBefore+1 and rope==ropesBefore,'rubber mode must create only the gun')
GetGroundZFor_3dCoord=function() return false,0 end
local polygons=0
DrawPoly=function(...)
 local args={...};polygons=polygons+1
 for i=1,9 do assert(args[i]==args[i] and math.abs(args[i])<10000,'mesh coordinates must be finite') end
 assert(args[10]<30 and args[13]==255,'hose must be opaque near-black')
end
api.drawHose(rubber);assert(polygons==Config.Wash.hose.segments*Config.Wash.hose.sides*2)
-- Vertical hose endpoints must not divide by zero.
positions[rubber.tool]=vec3(10,0,3);api.drawHose(rubber)
assert(api.animation(Config.Wash.tools.gun,false)==Config.Wash.tools.gun.anim)
assert(api.animation(Config.Wash.tools.gun,true)==Config.Wash.tools.gun.aimAnim)
assert(api.animation(Config.Wash.tools.sponge,false)==nil)
assert(api.animation(Config.Wash.tools.sponge,true)==Config.Wash.tools.sponge.anim)
api.stop(11);assert(created==deleted,'rubber-mode cleanup must remove gun')
-- The integrated custom clips must take over from all experimental IK.
local gun=Config.Wash.tools.gun
assert(gun.pose==nil)
assert(gun.anim.dict=='crimson_wash_custom_v6' and gun.anim.clip=='carry')
assert(gun.aimAnim.dict=='crimson_wash_custom_v6' and gun.aimAnim.clip=='spray')
assert(gun.hand.bone==57005 and close(gun.hand.pos.x,.085) and close(gun.hand.rot.x,-90) and close(gun.hand.pos.y,.025) and close(gun.hand.pos.z,-.040))
assert(not src:find('SetIkTarget',1,true) and not src:find('SetPedCanArmIk',1,true),'runtime IK must be removed')
assert(not src:find('GiveWeaponToPed',1,true),'integration must not grant weapons')
print('PASS: hose renderers, carry/spray states, custom carry/spray clip bindings and no IK/weapon grant, muzzle and cleanup')
