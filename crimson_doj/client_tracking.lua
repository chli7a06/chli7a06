local handles,last={},0
local function clear()for _,handle in pairs(handles)do RemoveBlip(handle)end;handles={}end
RegisterNetEvent('crimson_doj:trackingBlips',function(rows)
 last=GetGameTimer();local keep={}
 for _,row in ipairs(rows)do
  local handle=handles[row.citizenid]
  if not handle then handle=AddBlipForCoord(row.x,row.y,row.z);handles[row.citizenid]=handle;SetBlipSprite(handle,161);SetBlipColour(handle,5);SetBlipScale(handle,0.75);SetBlipAsShortRange(handle,false)end
  SetBlipCoords(handle,row.x,row.y,row.z);BeginTextCommandSetBlipName('STRING');AddTextComponentSubstringPlayerName('Tracking · '..row.citizenid);EndTextCommandSetBlipName(handle);keep[row.citizenid]=true
 end
 for cid,handle in pairs(handles)do if not keep[cid]then RemoveBlip(handle);handles[cid]=nil end end
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate',clear)
RegisterNetEvent('QBCore:Client:SetDuty',clear)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',clear)
AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName()then clear()end end)
CreateThread(function()while true do Wait(5000);if GetGameTimer()-last>15000 then clear()end end end)
