Config={}
dofile('crimson_doj/permissions.lua')
local expected={'DOJ Trainee','Lawyer in Training','Municipal Security Officer','Court Clerk','Private Defender','Public Defender','Chief Public Defender','Prosecutor','Deputy District Attorney','District Attorney','Attorney General','Judge','Senior Judge','Deputy Chief of Justice','Chief of Justice'}
for level=0,14 do assert(Config.DojGrades[tostring(level)].label==expected[level+1])end
assert(Config.ManagementMinGrade==12)
for level=0,14 do assert(CrimsonManagement({department='doj',grade=level})==(level>=12))end
local saved,threads={},{}
local job={label='My DOJ',defaultDuty=false,offDutyPay=true,grades={}}
for level=0,14 do job.grades[level]={name='Old '..level,payment=100+level,isboss=level==14,bankAuth=level>=13}end
CreateThread=function(fn)threads[#threads+1]=fn;fn()end
exports={qbx_core={GetJobs=function()return {doj=job}end,CreateJobs=function(_,data,commit)saved=data;assert(commit==false);return true end}}
dofile('crimson_doj/server_grade_names.lua')
assert(saved.doj.label=='My DOJ'and saved.doj.defaultDuty==false and saved.doj.offDutyPay==true)
for level=0,14 do local grade=saved.doj.grades[level];assert(grade.name==expected[level+1]and grade.payment==100+level and grade.isboss==(level==14)and grade.bankAuth==(level>=13));assert(job.grades[level].name=='Old '..level)end
Config.SyncDojGradeNames=false;saved=nil;threads[1]();assert(saved==nil)
print('PASS exact 15 DOJ ranks, Senior Judge gate and salary-preserving Qbox name sync')
