-- Qbox + Apex company banking bridge for the supplied lb-phone custom files.
CrimsonPhoneApex = {}
local busy={}
local prefix='crimson_apex_pending:'
local function amount(n)
 return type(n)=='number' and n==n and n%1==0 and n>=1 and n<=1000000
end
local function actor(src)
 local player=exports.qbx_core:GetPlayer(src)
 local p=player and player.PlayerData
 if not p or not p.job or not p.job.isboss or type(p.citizenid)~='string' then error('Company boss permission required',0) end
 return p
end
local function ready()
 if GetResourceState('apex_banking')~='started' or GetResourceState('qbx_core')~='started' then error('Start apex_banking and qbx_core first',0) end
end
local function treasury(job)
 local descriptor=exports.apex_banking:ResolveIban('BIZ:'..job)
 if type(descriptor)~='table' or descriptor.kind~='business' or descriptor.job~=job then error('Company treasury not found in Apex: '..job,0) end
 local value=tonumber(exports.apex_banking:GetBusinessBalance(job))
 if not value or value~=value or value==math.huge or value==-math.huge then error('Apex balance unavailable',0) end
 return value
end
local function notify(src,text)
 pcall(function()exports.apex_banking:Notify(src,text,'error',6000)end)
end
function CrimsonPhoneApex.Balance(src)
 local ok,value=pcall(function()ready();local p=actor(src);return treasury(p.job.name)end)
 if not ok then notify(src,tostring(value));return false end
 return value
end
local function businessChange(job,n,reason)
 local value,why
 if n>0 then value,why=exports.apex_banking:AddBusinessMoney(job,n,reason)
 else value,why=exports.apex_banking:RemoveBusinessMoney(job,-n,reason) end
 if value==true or (type(value)=='number' and value==value and value>=0 and value<math.huge) then return true end
 if value==false and ({bad_args=true,disabled=true,not_found=true,no_funds=true})[why] then return false end
 error('Apex operation outcome uncertain',0)
end
function CrimsonPhoneApex.Transfer(src,n,withdraw)
 if not amount(n) then notify(src,'Enter a positive whole amount (maximum $1,000,000)');return false end
 local p,job
 local ownerOk,ownerError=pcall(function()ready();p=actor(src);job=p.job.name end)
 if not ownerOk then notify(src,tostring(ownerError));return false end
 if busy[job] or GetResourceKvpString(prefix..job) then notify(src,'Company transfer pending; ask an administrator to review');return false end
 busy[job]=true
 local ok,value=pcall(function()
  local balance=treasury(job)
  local live=actor(src)
  if live.citizenid~=p.citizenid or live.job.name~=job then error('Character or job changed',0) end
  if withdraw and balance<n then error('Insufficient company balance',0) end
  if not withdraw and (tonumber(live.money and live.money.bank) or 0)<n then error('Insufficient personal bank balance',0) end
  local entry={citizenid=p.citizenid,job=job,amount=n,withdraw=withdraw,time=os.time(),stage='first-leg'}
  local function stage(text)
   entry.stage=text;SetResourceKvp(prefix..job,json.encode(entry))
  end
  local function clear()DeleteResourceKvp(prefix..job)end
  local reason='lb-phone Apex '..(withdraw and 'company withdrawal' or 'company deposit')
  stage('first-leg')
  local first
  if withdraw then first=businessChange(job,-n,reason)
  else first=exports.qbx_core:RemoveMoney(p.citizenid,'bank',n,reason) end
  if first~=true then
   if first==false then clear();error('Transfer rejected without moving funds',0) end
   error('First transfer outcome uncertain',0)
  end
  stage('second-leg')
  local second
  if withdraw then second=exports.qbx_core:AddMoney(p.citizenid,'bank',n,reason)
  else second=businessChange(job,n,reason) end
  if second~=true then
   if second~=false then error('Second transfer outcome uncertain',0) end
   stage('refund')
   local refunded
   if withdraw then refunded=businessChange(job,n,reason..' refund')
   else refunded=exports.qbx_core:AddMoney(p.citizenid,'bank',n,reason..' refund') end
   if refunded==true then clear();error('Transfer rejected; funds refunded',0) end
   error('Refund outcome uncertain',0)
  end
  stage('completed')
  clear()
  return treasury(job)
 end)
 busy[job]=nil
 if not ok then
  print('[lb-phone Apex] '..tostring(value)..(GetResourceKvpString(prefix..job) and ' | locked for review: '..job or ''))
  notify(src,GetResourceKvpString(prefix..job) and 'Transfer outcome needs administrator review. Do not retry.' or tostring(value))
  return false
 end
 return value
end
-- Clears only the review marker. Never moves funds or replays a transfer.
RegisterCommand('phoneapexresolve',function(src,args)
 if src~=0 then return end
 local job=args[1]
 if not job or busy[job] or not args[2] then print('Usage: phoneapexresolve <job> <verified reason>');return end
 local pending=GetResourceKvpString(prefix..job)
 if not pending then print('[lb-phone Apex] No pending transfer');return end
 print('[lb-phone Apex] Verified review cleared: '..pending..' | '..table.concat(args,' ',2))
 DeleteResourceKvp(prefix..job)
end,true)
