-- Update only existing native DOJ grade names; keep salaries, boss/bank flags and levels.
-- Qbox CreateJobs(..., false) updates runtime definitions without rewriting shared/jobs.lua.
CreateThread(function()
 if Config.SyncDojGradeNames==false then return end
 local function copy(value)
  if type(value)~='table'then return value end
  local result={}for key,item in pairs(value)do result[key]=copy(item)end;return result
 end
 local ok,err=pcall(function()
  local jobs=exports.qbx_core:GetJobs();local original=jobs and jobs.doj
  if not original or type(original.grades)~='table'then print('[Crimson grades] Native doj job missing; MDT labels still available');return end
  local updated=copy(original);local changed=false;local missing={}
  for level=0,14 do
   local entry=Config.DojGrades[tostring(level)]
   local grade=updated.grades[level]or updated.grades[tostring(level)]
   if grade and entry then
    if grade.name~=entry.label then grade.name=entry.label;changed=true end
   elseif entry then missing[#missing+1]=tostring(level)end
  end
  if #missing>0 then print('[Crimson grades] Missing native DOJ levels: '..table.concat(missing,',')..'. No salary or new rank was invented.')end
  if changed then
   local success,message=exports.qbx_core:CreateJobs({doj=updated},false)
   if success==false then error(message or 'Qbox rejected updated grade names')end
   print('[Crimson grades] Existing native DOJ grade names updated; pay and flags preserved')
  end
 end)
 if not ok then print('[Crimson grades] Native label sync unavailable: '..tostring(err))end
end)
