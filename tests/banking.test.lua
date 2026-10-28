local n=0
local function check(v)assert(v)n=n+1 end
local states={['Renewed-Banking']='started'}
GetResourceState=function(r)return states[r] or 'missing'end
Config={Integrations={},Banking={provider='auto',accounts={mechanic='garage'}}}
exports={['Renewed-Banking']={getAccountMoney=function(_,a)check(a=='garage')return 123 end,getAccountTransactions=function()return {}end,addAccountMoney=function()return true end}}
dofile('crimson_doj/server_banking.lua')
local b=CrimsonBankProvider();check(b.name=='Renewed-Banking');check(b.balance('mechanic')==123);check(b.credit('mechanic',5,''))
states['qb-banking']='started';check(not pcall(CrimsonBankProvider))
Config.Banking.provider='qb-banking'
local result=1
exports['qb-banking']={GetAccount=function(_,a)if a=='garage' then return {account_balance=0} end end,AddMoney=function()return result end}
b=CrimsonBankProvider();check(b.balance('mechanic')==0);check(b.balance('missing')==nil);check(b.credit('mechanic',5,''))
result=0;check(not pcall(b.credit,'mechanic',5,''));result=false;check(b.credit('mechanic',5,'')==false)
Config.Banking={provider='custom',resource='mybank',balanceExport='ReadCompany',balanceField='money',accounts={mechanic='society_mechanic'}}
states.mybank='started';exports.mybank={ReadCompany=function(_,a)check(a=='society_mechanic')return {money=777}end}
b=CrimsonBankProvider();check(b.balance('mechanic')==777);check(b.credit==nil)
Config.Banking.provider='apex_banking';states.apex_banking='started';check(not pcall(CrimsonBankProvider))
CrimsonBankAdapters.apex_banking={balance=function()return 800 end};b=CrimsonBankProvider();check(b.balance('mechanic')==800)
states.apex_banking='stopped';check(not pcall(CrimsonBankProvider))
Config.Banking={provider='auto'};states={};check(not pcall(CrimsonBankProvider))
print('PASS '..n..' banking adapter checks')
