local players={
 [1]={job={name='doj',onduty=true}},[2]={job={name='police',onduty=true}},
 [3]={job={name='sheriff',onduty=true}},[4]={job={name='mechanic',onduty=true}},
 [5]={job={name='doj',onduty=false}},[6]={job={name='doj',onduty=true}},
}
Config={JobBlips={enabled=true,jobs={doj=true,police=true,sheriff=true}}}
exports={qbx_core={GetPlayer=function(_,id)return {PlayerData=players[id]}end}}
GetPlayers=function()return {'1','2','3','4','5','6'}end
GetPlayerPed=function(id)return id end
GetEntityCoords=function(id)return {x=id,y=2,z=3}end
GetEntityHeading=function()return 90 end
GetPlayerRoutingBucket=function(id)return id==6 and 10 or 0 end
CreateThread=function()end
AddEventHandler=function()end
local sent={}
TriggerClientEvent=function(_,id,rows)sent[id]=rows end
dofile('crimson_doj/server_blips.lua')
CrimsonBlipTick()
assert(#sent[1]==2 and sent[1][1].job=='police' and sent[1][2].job=='sheriff')
assert(#sent[2]==1 and sent[2][1].job=='doj','police see DOJ, no duplicated Origen police markers')
assert(#sent[3]==1 and sent[3][1].source==1)
assert(not sent[4] and not sent[5],'no coordinates to mechanics/off-duty DOJ')
assert(#sent[6]==0,'routing bucket isolation')
players[1].job.name='mechanic';sent={};CrimsonBlipTick()
assert(#sent[1]==0 and #sent[2]==0 and #sent[3]==0,'job change removes stale marker and clears former viewer')
Config.JobBlips.enabled=false;sent={};CrimsonBlipTick();assert(#sent[2]==0,'disable clears prior viewers')
local events={}
RegisterNetEvent=function(name,fn)events[name]=fn end
AddEventHandler=function(name,fn)events[name]=fn end
local created,removed=0,0
GetGameTimer=function()return 100 end
AddBlipForCoord=function()created=created+1;return created end
RemoveBlip=function()removed=removed+1 end
SetBlipSprite=function()end;SetBlipColour=function()end;SetBlipScale=function()end
SetBlipAsShortRange=function()end;SetBlipCoords=function()end;SetBlipRotation=function()end
BeginTextCommandSetBlipName=function()end;AddTextComponentSubstringPlayerName=function()end;EndTextCommandSetBlipName=function()end
GetCurrentResourceName=function()return 'crimson_doj'end
Config.JobBlips.enabled=true
dofile('crimson_doj/client_blips.lua')
local row={source=2,job='police',name='Test',x=1,y=2,z=3,heading=0}
events['crimson_doj:jobBlips']({row});events['crimson_doj:jobBlips']({row});assert(created==1,'updates reuse map handle')
events['QBCore:Client:OnJobUpdate']();assert(removed==1,'job change removes stale markers immediately')
events['crimson_doj:jobBlips']({row});events['onResourceStop']('crimson_doj');assert(removed==2,'resource cleanup')
print('PASS DOJ/Origen-compatible blip audience, duty, job change and routing isolation')
