local handlers,called={},{}
AddEventHandler=function(k,v)handlers[k]=v end
GetResourceState=function()return 'started'end
GetGameTimer=function()return 10000 end
GetPlayerPed=function(src)return src end
GetEntityCoords=function()return {x=1,y=2,z=3}end
exports={crimson_doj={CreateDispatch=function(_,data)called[#called+1]=data end}}
cachedLicenses={CID={weapon=true}}
dofile('integrations/origen-police/crimson_bridge.lua')
source=12;handlers['SendAlert:police']({title=string.rep('A',200),message='Alert',coords={x=9999,y=9999,z=9999}})
assert(#called==1 and #called[1].title==160 and called[1].coords.x==1,'bounded import uses authoritative source position')
handlers['SendAlert:police']({title='Spam'});assert(#called==1,'repeat alerts rate limited')
source=0;handlers['SendAlert:police']({title='Server spoof'});assert(#called==1,'client source required')
handlers['crimson_doj:licenseChanged']('CID');assert(cachedLicenses.CID==nil,'native license changes invalidate Origen cache')
print('PASS Origen bridge source, bounds, rate and license-cache checks')
