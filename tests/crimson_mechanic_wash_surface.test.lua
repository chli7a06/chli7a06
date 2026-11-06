local vector={}
vector.__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
vector.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
vec3=function(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('crimson-mechanic/config.lua')
cache={ped=1}
local base=vec3(10,20,30)
DoesEntityExist=function() return true end
IsEntityAVehicle=function() return true end
NetworkDoesEntityExistWithNetworkId=function(id) return id==99 end
NetworkGetEntityFromNetworkId=function() return 10 end
GetEntityCoords=function(e) return e==1 and vec3(10,20,30) or base end
GetOffsetFromEntityGivenWorldCoords=function(_,x,y,z) return vec3(x,y,z)-base end
GetOffsetFromEntityInWorldCoords=function(_,x,y,z) return base+vec3(x,y,z) end
local clock=10000
GetGameTimer=function() return clock end
AddDecal=function() return 0 end
IsDecalAlive=function() return false end
RemoveDecal=function() end
local textureLoads=0
CreateRuntimeTxd=function() return 1 end
CreateRuntimeTextureFromImage=function() textureLoads=textureLoads+1 end
local triangles,types={},{}
DrawSpritePoly=function(...)
 local a={...};triangles[#triangles+1]=a;types[a[15]]=true
 for i=1,9 do assert(a[i]==a[i] and math.abs(a[i])<10000) end
end
dofile('crimson-mechanic/client/wash_surface.lua')
local S=CrimsonWashSurface
local session={vehicle=10,netId=99}
local a,b=base+vec3(0,0,1),base+vec3(1.2,0,1)
assert(S.hit(session,'foam',a,vec3(0,0,1),0))
assert(not S.hit(session,'foam',b,vec3(0,0,1),50),'sampling must be throttled')
assert(S.hit(session,'foam',b,vec3(0,0,1),200))
assert(#session.surfacePatches==2)
local revision=session.surfaceRevision
assert(not S.hit(session,'foam',b,vec3(0,0,1),400))
assert(session.surfaceRevision==revision,'unchanged coating must not trigger new snapshots')
local owner,spectator={},{}
S.apply(owner,S.snapshot(session));S.apply(spectator,S.snapshot(session))
assert(owner.surface.patches~=spectator.surface.patches)
S.draw(spectator);assert(#triangles==8 and types.foam and textureLoads==2)
local firstX=triangles[1][1]
-- Foam stays visible after releasing spray and follows the car's transform.
base=base+vec3(2,0,0);triangles={};S.draw(spectator)
assert(#triangles==8 and math.abs(triangles[1][1]-firstX-2)<.00001 and textureLoads==2)
assert(S.hit(session,'water',base+vec3(0,0,1),vec3(0,0,1),600))
assert(session.surfacePatches[1].kind=='water' and session.surfacePatches[2].kind=='foam','rinse must remove only nearby soap')
S.apply(spectator,S.snapshot(session));triangles={};types={};S.draw(spectator)
assert(types.water and types.foam,'wet patches and remaining foam must both render')
local decals,removed={},0
AddDecal=function(kind,...)
 assert(kind==1040,'wet bodywork must use native water splatter')
 decals[1]=true;return 1
end
IsDecalAlive=function(id) return decals[id]==true end
RemoveDecal=function(id) assert(decals[id]);decals[id]=nil;removed=removed+1 end
clock=11001;triangles={};types={};S.draw(spectator)
assert(decals[1] and not types.water and types.foam,'native wetness must replace the water highlight mesh when available')
S.clear(spectator);assert(removed==1 and not spectator.surface,'cleanup must remove only our own native water decals')
for i=1,100 do
 S.hit(session,'foam',base+vec3((i%10)*.4,math.floor(i/10)*.4,1),vec3(0,0,1),600+i*200)
end
assert(#session.surfacePatches<=Config.Wash.surface.maxPatches)
S.apply(spectator,{vehicle=99,revision=999,patches={{x=0/0,y=0,z=0,nx=0,ny=0,nz=1,kind='foam'}}})
assert(#spectator.surface.patches==0,'invalid replicated geometry must be ignored')
S.apply(spectator,nil);assert(not spectator.surface,'ending wash must clear the coating')
print('PASS: persistent foam, local rinsing, wet patches, spectator snapshots, moving-car attachment and bounded geometry')
