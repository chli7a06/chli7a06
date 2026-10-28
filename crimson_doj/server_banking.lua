-- Server-only adapters. Never accept provider, export or account IDs from NUI.
CrimsonBankAdapters = CrimsonBankAdapters or {}
local function call(resource,method,...)
 local proxy=exports[resource]
 return proxy[method](proxy,...)
end
local function finite(value)
 local n=tonumber(value)
 if n and n==n and n~=math.huge and n~=-math.huge then return n end
end
function CrimsonBankProvider()
 local c=Config.Banking or {}
 local selected=c.provider
 if selected==nil then selected=Config.Integrations.banking end
 if selected=='auto' then
  local found={}
  for _,name in ipairs({'Renewed-Banking','qb-banking','apex_banking'}) do
   if GetResourceState(name)=='started' then found[#found+1]=name end
  end
  if #found~=1 then error('Select Config.Banking.provider explicitly: no bank or multiple banks detected',0) end
  selected=found[1]
 end
 local adapter=CrimsonBankAdapters[selected]
 local resource=adapter and adapter.resource or selected
 if selected=='custom' then resource=c.resource end
 if type(resource)~='string' or GetResourceState(resource)~='started' then error('Configured banking resource is not started',0) end
 local b={name=selected}
 local function account(job)return (c.accounts or {})[job] or job end
 if selected=='Renewed-Banking' then
  b.balance=function(job)return call(resource,'getAccountMoney',account(job))end
  b.transactions=function(job)return call(resource,'getAccountTransactions',account(job))end
  b.credit=function(job,amount,reason)return call(resource,'addAccountMoney',account(job),amount)end
  b.history=function(job,cid,kind,amount,reason,reference)
   call(resource,'handleTransaction',account(job),'Crimson '..kind,amount,reason,cid,account(job),'deposit',reference)
   call(resource,'handleTransaction',cid,'Crimson '..kind,amount,reason,cid,account(job),'withdraw',reference)
  end
 elseif selected=='qb-banking' then
  -- GetAccount distinguishes missing accounts from a genuine zero balance.
  b.balance=function(job)local row=call(resource,'GetAccount',account(job));return type(row)=='table' and row.account_balance or nil end
  b.transactions=function()return {}end
  b.credit=function(job,amount,reason)
   local result=call(resource,'AddMoney',account(job),amount,reason)
   -- qb-banking returns affected rows. Zero is NOT success in Lua.
   if result==true or (type(result)=='number' and result>0) then return true end
   if result==false then return false end
   error('Bank credit outcome uncertain',0)
  end
 elseif selected=='custom' then
  if type(c.balanceExport)~='string' then error('Configure the custom bank balanceExport first',0) end
  b.balance=function(job)
   local value=call(resource,c.balanceExport,account(job))
   if c.balanceField and type(value)=='table' then value=value[c.balanceField] end
   return value
  end
  b.transactions=function()return {}end
  -- No generic write API is guessed. Register a verified adapter for payments.
 elseif adapter then
  b.balance=function(job)return adapter.balance(account(job))end
  b.transactions=function(job)return adapter.transactions and adapter.transactions(account(job)) or {}end
  if adapter.credit then b.credit=function(job,amount,reason)
   local result=adapter.credit(account(job),amount,reason)
   if type(result)~='boolean' then error('Custom bank credit outcome uncertain',0) end
   return result
  end end
 else
  error('No verified adapter for '..tostring(selected)..'. Configure custom read export or install a server adapter.',0)
 end
 local read=b.balance
 b.balance=function(job)return finite(read(job))end
 return b
end
