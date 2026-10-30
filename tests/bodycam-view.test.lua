local n=0
local function check(v,label)assert(v,label);n=n+1 end
Config={Bodycam={}}
local callbacks,events,handlers,threads={},{},{},{}
local ped,dead,rendering=1,false,0
local pedMode,vehicleMode=1,2
local threadMode,lastCapture=false,nil
GetCurrentResourceName=function()return 'crimson_doj'end
PlayerPedId=function()return ped end
DoesEntityExist=function()return true end
IsEntityDead=function()return dead end
GetRenderingCam=function()return rendering end
GetFollowPedCamViewMode=function()return pedMode end
GetFollowVehicleCamViewMode=function()return vehicleMode end
SetFollowPedCamViewMode=function(mode)pedMode=mode end
SetFollowVehicleCamViewMode=function(mode)vehicleMode=mode end
SetNuiFocus=function()error('bodycam must never alter MDT focus')end
CreateCamWithParams=function()error('must use native first person')end
CreateThread=function(fn)threads[#threads+1]=fn end
Wait=function()if threadMode then coroutine.yield()end end
lib={callback={register=function(name,fn)callbacks[name]=fn end,await=function(name)lastCapture=name;return {ok=true}end}}
RegisterNetEvent=function(name,fn)events[name]=fn end
AddEventHandler=function(name,fn)handlers[name]=fn end
dofile('crimson_doj/client_bodycam.lua')
local prepare=callbacks['crimson_doj:prepareBodycamView']
check(prepare().ok and pedMode==4 and vehicleMode==4,'native first person prepared before capture, on foot and in vehicles')
events['crimson_doj:bodycamStatus']({active=true});check(#threads==1,'status does not overwrite original saved view')
pedMode=0;vehicleMode=0
local loop=coroutine.create(threads[1]);threadMode=true;assert(coroutine.resume(loop));threadMode=false
check(pedMode==4 and vehicleMode==4,'perspective stays first person during recording')
events['crimson_doj:bodycamStatus']({active=false});check(pedMode==1 and vehicleMode==2 and not CrimsonBodycamView.isActive(),'completion restores both original modes')
prepare();events['QBCore:Client:OnPlayerUnload']();check(pedMode==1 and vehicleMode==2,'logout restores view')
prepare();handlers.onResourceStop('other');check(CrimsonBodycamView.isActive(),'unrelated resource stop leaves recording')
handlers.onResourceStop('crimson_doj');check(pedMode==1 and vehicleMode==2,'resource stop restores view')
rendering=999;check(not prepare().ok and not CrimsonBodycamView.isActive(),'foreign scripted camera blocks preparation')
rendering=0;prepare();dead=true;loop=coroutine.create(threads[#threads]);threadMode=true;assert(coroutine.resume(loop));threadMode=false
check(not CrimsonBodycamView.isActive()and lastCapture=='crimson_doj:stopOwnBodycam'and pedMode==1,'death restores view and stops own recording')
dead=false;Config.Bodycam.view='gameplay';check(prepare().ok and pedMode==1,'gameplay optout retained')
print('PASS '..n..' native first-person recording and restoration checks')
