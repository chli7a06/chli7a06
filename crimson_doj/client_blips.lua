local blips={}
local lastUpdate=0
local function clear()
 for _,handle in pairs(blips) do RemoveBlip(handle) end
 blips={}
end
RegisterNetEvent('crimson_doj:jobBlips',function(rows)
 lastUpdate=GetGameTimer()
 local keep={}
 local settings=Config.JobBlips
 if not settings or not settings.enabled then clear() return end
 for _,unit in ipairs(rows) do
  local handle=blips[unit.source]
  if not handle then
   handle=AddBlipForCoord(unit.x,unit.y,unit.z)
   SetBlipSprite(handle,settings.sprite or 1)
   SetBlipColour(handle,settings.colour or 1)
   SetBlipScale(handle,settings.scale or 0.8)
   SetBlipAsShortRange(handle,false)
   blips[unit.source]=handle
  end
  SetBlipCoords(handle,unit.x,unit.y,unit.z)
  SetBlipRotation(handle,math.floor(unit.heading or 0))
  BeginTextCommandSetBlipName('STRING')
  AddTextComponentSubstringPlayerName(unit.job:upper()..' · '..unit.name)
  EndTextCommandSetBlipName(handle)
  keep[unit.source]=true
 end
 for id,handle in pairs(blips) do if not keep[id] then RemoveBlip(handle) blips[id]=nil end end
end)
RegisterNetEvent('QBCore:Client:OnJobUpdate',clear)
RegisterNetEvent('QBCore:Client:SetDuty',clear)
RegisterNetEvent('QBCore:Client:OnPlayerUnload',clear)
AddEventHandler('onResourceStop',function(name)if name==GetCurrentResourceName() then clear() end end)
CreateThread(function()
 while true do
  Wait(5000)
  if GetGameTimer()-lastUpdate>15000 then clear() end
 end
end)
