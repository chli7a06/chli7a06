-- Regress the actual task controller and heading limiter, without running FiveM.
vec3=function(x,y,z) return {x=x,y=y,z=z} end
vec4=function(x,y,z,w) return {x=x,y=y,z=z,w=w} end
Lang={wash={}};cache={ped=1}
dofile('crimson-mechanic/config.lua')
CreateThread=function() end
AddStateBagChangeHandler=function() end
RegisterCommand=function() end
RegisterKeyMapping=function() end
local clock, reported, stops, heading=0,true,0,0
local plays={}
TaskPlayAnim=function(_,dict,clip) plays[#plays+1]={at=clock,dict=dict,clip=clip} end
StopAnimTask=function() stops=stops+1 end
IsEntityPlayingAnim=function() return reported end
GetEntityHeading=function() return heading end
SetEntityHeading=function(_,value) heading=value end
local file=assert(io.open('crimson-mechanic/client/wash.lua'));local source=file:read('*a');file:close()
source=source:gsub('`[^`]+`','0')
source=source:sub(1,assert(source:find('local function startWash',1,true))-1)
local api=assert(load(source..'\nreturn {animation=updateWashAnimation,turn=turnTo}'))()
local gun=Config.Wash.tools.gun
local state={}
for frame=0,179 do
 clock=frame*1000/60
 reported=clock>=400 and not (clock>=1500 and clock<1650)
 api.animation(state,1,gun.anim,clock)
end
assert(#plays==1,'blend-in and one transient false report must not restart the animation')
clock=3000;api.animation(state,1,gun.aimAnim,clock)
assert(#plays==2 and stops==0,'carry -> spray must crossfade without stopping the old task')
clock=3100;api.animation(state,1,gun.anim,clock)
assert(#plays==3 and stops==0,'spray -> carry must also crossfade')
clock=3200;api.animation(state,1,nil,clock);assert(stops==1)
-- A genuinely interrupted task still recovers, with a bounded replay frequency.
state={};plays={};reported=false
for frame=0,239 do
 clock=frame*1000/60;api.animation(state,1,gun.aimAnim,clock)
end
assert(#plays>=2 and #plays<=4)
for i=2,#plays do assert(plays[i].at-plays[i-1].at>=1200) end
-- Body turn speed must be the same at 30 and 144 fps.
for _,fps in ipairs({30,144}) do
 heading=0
 for frame=1,fps/2 do api.turn(1,90,1000/fps) end
 assert(math.abs(heading-60)<.0001,'heading must be limited by elapsed time, not frame count')
end
heading=10;api.turn(1,12,16);assert(heading==10,'small heading noise must stay inside the deadband')
heading=350;api.turn(1,10,10);assert(math.abs(heading-351.2)<.0001,'turn through the shortest wraparound direction')
print('PASS: no per-frame animation restart, smooth pose transitions, bounded recovery and frame-rate independent turning')
