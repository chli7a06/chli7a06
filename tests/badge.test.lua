local commands,callbacks,events,handlers={},{},{},{}
local now=10000
local chief={citizenid='CHIEF',source=1,job={name='doj',onduty=true,grade={level=13,name='Chief'}}}
local holder={citizenid='HOLDER',source=2,job={name='doj',onduty=true,grade={level=0,name='Student'}}}
local players={[1]=chief,[2]=holder}
local item,registry=nil,{}
local adds=0
Config={Jobs={doj={department='doj',read=0}},BadgeChiefMinGrade=13}
exports={qbx_core={GetPlayer=function(_,id)return players[id] and {PlayerData=players[id]}end,GetPlayerByCitizenId=function(_,cid)if cid=='HOLDER' then return {PlayerData=holder}end end},ox_inventory={GetSlot=function()return item end,AddItem=function(_,id,name,count,meta)assert((id==2 and meta.owner=='HOLDER') or (id==1 and meta.owner=='CHIEF'));item={name=name,metadata=meta};adds=adds+1;return true end}}
lib={callback={register=function(k,v)callbacks[k]=v end}}
RegisterCommand=function(k,v)commands[k]=v end
RegisterNetEvent=function(k,v)handlers[k]=v end
AddEventHandler=function(k,v)handlers[k]=v end
GetResourceState=function()return 'started'end
GetGameTimer=function()return now end
GetPlayerPed=function(id)return id end
GetEntityCoords=function(id)return {x=id==3 and 20 or 0,y=0,z=0}end
GetPlayers=function()return {'1','2','3','4'}end
GetPlayerRoutingBucket=function(id)return id==4 and 10 or 0 end
TriggerClientEvent=function(name,target,data)events[#events+1]={name=name,target=target,data=data}end
SetTimeout=function()end
MySQL={scalar={await=function()return 'UUID-1'end},insert={await=function(_,values)registry[values[1]]={display_name=values[3],owner=values[2]};return 1 end},single={await=function(_,args)local r=registry[args[1]];if r and r.owner==args[2] then return r end end},update={await=function()end}}
dofile('crimson_doj/server_badge.lua')
assert(next(commands)==nil,'no self-issue command')
local issue,show=callbacks['crimson_doj:issueBadge'],callbacks['crimson_doj:showBadge']
assert(not issue(2,{citizenid='HOLDER',name='Student'}).ok,'ordinary staff cannot issue')
chief.job.grade.level=12;assert(not issue(1,{citizenid='HOLDER',name='Student'}).ok,'rank twelve cannot issue');chief.job.grade.level=13
assert(not issue(1,{citizenid='HOLDER',name='x'}).ok,'invalid names denied')
assert(issue(1,{citizenid='HOLDER',name='Official Custom Name'}).ok and adds==1,'chief issues named badge')
assert(not issue(1,{citizenid='HOLDER',name='Again'}).ok,'issuance rate limit')
assert(not show(2,'1').ok)
assert(show(2,1).ok)
assert(#events==2 and events[1].target==2 and events[2].target==1,'only holder and nearby same-bucket viewer')
assert(events[1].data.name=='Official Custom Name' and events[1].data.isOwner and not events[2].data.isOwner,'database name and owner flag')
assert(not show(2,1).ok,'show rate limited')
local token=events[1].data.presentation
source=1;handlers['crimson_doj:hideBadge'](token);assert(#events==2,'viewer cannot hide another holder presentation for everyone')
source=2;handlers['crimson_doj:hideBadge'](token);assert(#events==4 and events[3].name=='crimson_doj:badgeHide','holder dismiss hides recipient cards')
now=20000;item.metadata.owner='OTHER';assert(not show(2,1).ok,'transferred badge denied')
item.metadata.owner='HOLDER';holder.job.onduty=false;assert(not show(2,1).ok,'off duty denied')
holder.job.onduty=true;item.metadata.badge_ticket=nil;assert(not show(2,1).ok,'old self-issued credential rejected')
now=30000
assert(issue(1,{citizenid='  holder  ',name='Official Again'}).ok,'recipient ID trimmed and matched to canonical online ID')
local missing=issue(1,{citizenid='NOTONLINE',name='Unknown'})
assert(not missing.ok and missing.error:find('not found online',1,true),'missing ID has distinct diagnostic')
now=40000
assert(issue(1,{citizenid=' chief ',name='Chief Name'}).ok,'chief may issue own credential using canonical character ID')
print('PASS badge authorization, chief issuance, database identity, audience and dismissal checks')
