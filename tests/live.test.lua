dofile('crimson_doj/config.lua');dofile('crimson_doj/defaults.lua')
local threads,events,log={},{},0
local stopped,tokens=0,0
CreateThread=function(fn)threads[#threads+1]=fn end
AddEventHandler=function(name,fn)events[name]=fn end
Wait=function()coroutine.yield()end
GetConvar=function()return 'https://stream.example.workers.dev'end
GetResourceState=function()return 'started'end
GetCurrentResourceName=function()return 'crimson_doj'end
SetTimeout=function()end
TriggerClientEvent=function()end
promise={new=function()return {resolve=function(self,value)self.value=value end}end}
Citizen={Await=function(p)return p.value end}
exports={screencapture={startLiveStream=function(_,src,options,cb)assert(src==1 and options.maxViewers==10);cb({status='success'});return 'S1'end,stopLiveStream=function()stopped=stopped+1 end,createLiveStreamViewerToken=function(_,stream,cb)tokens=tokens+1;cb({streamId=stream,viewerToken='ONE-TIME-SECRET'})end}}
local host={source=1,scope='justice',department='doj',write=true,p={citizenid='HOST',job={name='doj'},charinfo={firstname='Test',lastname='Host'}}}
local viewer={source=2,scope='justice',department='police',write=true,p={citizenid='VIEW',job={name='police'}}}
local actors={[1]=host,[2]=viewer}
dofile('crimson_doj/server_live.lua')
local api=CrimsonLive({identity=function(src)return actors[src]end,reject=function(e)error(e,0)end,log=function()log=log+1 end})
Config.RequireBodycamItem=false
assert(not api.liveSources(host).configured,'live explicitly disabled by default')
Config.EnableLiveBodycam=true
assert(api.liveStart(host).started)
assert(#api.liveSources(viewer).rows==1,'department can list explicitly started host')
viewer.scope='medical';assert(not pcall(api.liveWatch,viewer,{citizenid='HOST'})and tokens==0,'cross-department token denied')
viewer.scope='justice';local grant=api.liveWatch(viewer,{citizenid='HOST'})
assert(grant.viewerToken=='ONE-TIME-SECRET'and grant.endpoint=='https://stream.example.workers.dev'and log==1,'authorized one-time viewer grant and audit')
local normal=exports.screencapture.createLiveStreamViewerToken
exports.screencapture.createLiveStreamViewerToken=function(_,id,cb)viewer.write=false;cb({streamId=id,viewerToken='DENIED'})end
assert(not pcall(api.liveWatch,viewer,{citizenid='HOST'}),'duty revoked while issuing token is denied')
viewer.write=true
exports.screencapture.createLiveStreamViewerToken=function(_,id,cb)cb({streamId='WRONG',viewerToken='DENIED'})end
assert(not pcall(api.liveWatch,viewer,{citizenid='HOST'}),'token for another stream denied')
exports.screencapture.createLiveStreamViewerToken=normal
local loop=coroutine.create(threads[1]);assert(coroutine.resume(loop));actors[2]=nil;assert(coroutine.resume(loop))
assert(stopped==1,'viewer access revocation stops underlying stream')
assert(#api.liveSources(host).rows==0)
print('PASS live bodycam configuration, consent, scope, token and revocation checks')
