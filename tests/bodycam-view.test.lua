local n=0
local function check(v,label)assert(v,label);n=n+1 end
Config={Bodycam={}}
local callbacks,events,handlers,threads={},{},{},{}
local cameras,rendering,active={},0,0
local nextHandle,destroyed,renderOff=10,0,0
local ped,dead,threadMode=1,false,false
local lastCoords,lastRot,lastCapture
GetCurrentResourceName=function()return 'crimson_doj'end
PlayerPedId=function()return ped end
DoesEntityExist=function()return true end
IsEntityDead=function()return dead end
GetRenderingCam=function()return rendering end
DoesCamExist=function(handle)return cameras[handle]~=nil end
GetPedBoneCoords=function(_,bone)assert(bone==24818);return {x=10,y=20,z=30}end
GetEntityForwardVector=function()return {x=0,y=1,z=0}end
GetGameplayCamRot=function()return {x=90,y=0,z=180}end
GetEntityHeading=function()return 0 end
CreateCamWithParams=function(_,x,y,z,rx,ry,rz,fov)nextHandle=nextHandle+1;cameras[nextHandle]={};lastCoords={x=x,y=y,z=z};lastRot={x=rx,y=ry,z=rz};check(fov==80,'bodycam uses configured bounded wide view');return nextHandle end
SetCamActive=function(handle)active=handle end
RenderScriptCams=function(enabled)if enabled then rendering=active else rendering=0;renderOff=renderOff+1 end end
DestroyCam=function(handle)cameras[handle]=nil;destroyed=destroyed+1 end
SetCamCoord=function(_,x,y,z)lastCoords={x=x,y=y,z=z}end
SetCamRot=function(_,x,y,z)lastRot={x=x,y=y,z=z}end
SetNuiFocus=function()error('bodycam must never alter MDT focus')end
CreateThread=function(fn)threads[#threads+1]=fn end
Wait=function()if threadMode then coroutine.yield()end end
lib={callback={register=function(name,fn)callbacks[name]=fn end,await=function(name)lastCapture=name;return {ok=true}end}}
RegisterNetEvent=function(name,fn)events[name]=fn end
AddEventHandler=function(name,fn)handlers[name]=fn end
dofile('crimson_doj/client_bodycam.lua')
local prepare=callbacks['crimson_doj:prepareBodycamView']
check(prepare().ok,'chest view prepared before capture')
check(lastCoords.x==10 and math.abs(lastCoords.y-20.28)<0.001 and math.abs(lastCoords.z-30.06)<0.001,'camera mounts ahead of chest bone, not behind player')
check(lastRot.x==45 and lastRot.z==-75,'look angles bounded to avoid turning into own torso')
local count=nextHandle;events['crimson_doj:bodycamStatus']({active=true});check(nextHandle==count,'active status does not duplicate prepared camera')
local loop=coroutine.create(threads[1]);threadMode=true;assert(coroutine.resume(loop));threadMode=false
check(lastCoords.y>20,'active frame follows chest position')
events['crimson_doj:bodycamStatus']({active=false,saved=true});check(rendering==0 and destroyed==1 and not CrimsonBodycamView.isActive(),'completion restores gameplay view and destroys owned camera')
prepare();events['QBCore:Client:OnPlayerUnload']();check(rendering==0 and destroyed==2,'logout restores view')
prepare();handlers.onResourceStop('other');check(CrimsonBodycamView.isActive(),'unrelated resource stop leaves camera')
handlers.onResourceStop('crimson_doj');check(rendering==0 and destroyed==3,'resource stop restores view')
rendering=999;local unavailable=prepare();check(not unavailable.ok and not CrimsonBodycamView.isActive(),'other scripted camera blocks recording preparation')
rendering=0;prepare();rendering=999;local before=renderOff;events['crimson_doj:bodycamStatus']({active=false,error='failure'});check(renderOff==before and rendering==999,'cleanup never disables a foreign camera')
rendering=0;prepare();dead=true;loop=coroutine.create(threads[#threads]);threadMode=true;assert(coroutine.resume(loop));threadMode=false
check(not CrimsonBodycamView.isActive()and lastCapture=='crimson_doj:stopOwnBodycam','death releases chest view and requests own capture stop')
dead=false;Config.Bodycam.view='gameplay';count=nextHandle;check(prepare().ok and nextHandle==count,'explicit gameplay mode preserves previous recording behavior')
print('PASS '..n..' chest-view preparation, perspective, ownership and cleanup checks')
