-- Vehicle-local foam and wet patches. The washer's existing replicated state
-- contains a bounded snapshot, so nearby/late viewers see the same coating.
CrimsonWashSurface = {}
local S = CrimsonWashSurface
local TXD = 'crimson_wash_surface'
local textureReady = false

local function config() return Config.Wash.surface or {} end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<20 end
local function vec(x,y,z) return vec3(x,y,z) end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function normal(x,y,z)
    local length=math.sqrt(x*x+y*y+z*z)
    if length<.001 then return end
    return vec(x/length,y/length,z/length)
end

function S.hit(session, kind, point, surfaceNormal, now)
    local c=config()
    if c.enabled==false or (kind~='foam' and kind~='water') or not point or not surfaceNormal then return end
    if not session.netId or not DoesEntityExist(session.vehicle) then return end
    if session.surfaceAt and now-session.surfaceAt<(c.sampleMs or 180) then return end
    local vehicle=session.vehicle
    local p=GetOffsetFromEntityGivenWorldCoords(vehicle,point.x,point.y,point.z)
    local tip=GetOffsetFromEntityGivenWorldCoords(vehicle,point.x+surfaceNormal.x,point.y+surfaceNormal.y,point.z+surfaceNormal.z)
    local n=normal(tip.x-p.x,tip.y-p.y,tip.z-p.z)
    if not n or not finite(p.x) or not finite(p.y) or not finite(p.z) then return end
    session.surfaceAt=now
    local patches=session.surfacePatches or {}
    session.surfacePatches=patches
    local nearest, gap, changed=nil,math.huge,false
    for _,patch in ipairs(patches) do
        local d=distance(p,patch)
        if d<gap then nearest,gap=patch,d end
        -- Rinse soap only around the actual impact, leaving other panels coated.
        if kind=='water' and patch.kind=='foam' and d<(c.rinseRadius or .75) then patch.kind='water';changed=true end
    end
    if nearest and gap<(c.patchSize or .6)*.35 then
        if nearest.kind~=kind then nearest.kind=kind;changed=true end
    else
        if #patches>=math.min(64,c.maxPatches or 48) then table.remove(patches,1) end
        patches[#patches+1]={x=p.x,y=p.y,z=p.z,nx=n.x,ny=n.y,nz=n.z,kind=kind}
        changed=true
    end
    if not changed then return false end
    session.surfaceRevision=(session.surfaceRevision or 0)+1
    return true
end

function S.snapshot(session)
    if not session.netId or not session.surfacePatches then return end
    return {vehicle=session.netId,revision=session.surfaceRevision,patches=session.surfacePatches}
end

function S.clear(visual)
    if visual.surface then
        for _,p in ipairs(visual.surface.patches) do
            if p.decal and p.decal~=0 then RemoveDecal(p.decal) end
        end
    end
    visual.surface=nil
end

local function patchKey(p)
    return ('%s:%.4f:%.4f:%.4f:%.3f:%.3f:%.3f'):format(p.kind,p.x,p.y,p.z,p.nx,p.ny,p.nz)
end

function S.apply(visual, data)
    if type(data)~='table' or type(data.vehicle)~='number' or data.vehicle<=0
        or data.vehicle>=2147483647 or data.vehicle%1~=0 or type(data.patches)~='table' then
        S.clear(visual)
        return
    end
    local old=visual.surface
    if old and old.vehicle==data.vehicle and old.revision==data.revision then return end
    local previous={}
    if old then for _,p in ipairs(old.patches) do previous[patchKey(p)]=p end end
    local patches={}
    for i=1,math.min(#data.patches,64,config().maxPatches or 48) do
        local p=data.patches[i]
        if type(p)=='table' and (p.kind=='foam' or p.kind=='water')
            and finite(p.x) and finite(p.y) and finite(p.z)
            and finite(p.nx) and finite(p.ny) and finite(p.nz) then
            local n=normal(p.nx,p.ny,p.nz)
            if n then
                local patch={x=p.x,y=p.y,z=p.z,nx=n.x,ny=n.y,nz=n.z,kind=p.kind}
                local key=patchKey(patch)
                local prior=previous[key]
                if prior then patch.decal,patch.decalAt=prior.decal,prior.decalAt;previous[key]=nil end
                patches[#patches+1]=patch
            end
        end
    end
    for _,p in pairs(previous) do if p.decal and p.decal~=0 then RemoveDecal(p.decal) end end
    visual.surface={vehicle=data.vehicle,revision=data.revision,patches=patches}
end

local function textures()
    if textureReady then return end
    local txd=CreateRuntimeTxd(TXD)
    CreateRuntimeTextureFromImage(txd,'foam','textures/wash_foam.png')
    CreateRuntimeTextureFromImage(txd,'water','textures/wash_water.png')
    textureReady=true
end

function S.draw(visual)
    local data,c=visual.surface,config()
    if not data or c.enabled==false or #data.patches==0 then return end
    if not NetworkDoesEntityExistWithNetworkId(data.vehicle) then return end
    local vehicle=NetworkGetEntityFromNetworkId(data.vehicle)
    if vehicle==0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    if #(GetEntityCoords(vehicle)-GetEntityCoords(cache.ped))>(c.distance or 65) then return end
    textures()
    local half=(c.patchSize or .6)*.5
    for _,p in ipairs(data.patches) do
        local n=vec(p.nx,p.ny,p.nz)
        local ref=math.abs(n.z)<.9 and vec(0,0,1) or vec(1,0,0)
        local u=normal(n.y*ref.z-n.z*ref.y,n.z*ref.x-n.x*ref.z,n.x*ref.y-n.y*ref.x)
        local v=vec(n.y*u.z-n.z*u.y,n.z*u.x-n.x*u.z,n.x*u.y-n.y*u.x)
        local function corner(a,b)
            return GetOffsetFromEntityInWorldCoords(vehicle,
                p.x+n.x*.006+half*(u.x*a+v.x*b),
                p.y+n.y*.006+half*(u.y*a+v.y*b),
                p.z+n.z*.006+half*(u.z*a+v.z*b))
        end
        local a,b,d,e=corner(-1,-1),corner(1,-1),corner(1,1),corner(-1,1)
        local foam=p.kind=='foam'
        local r,g,blue,alpha=foam and 255 or 195,foam and 255 or 225,255,foam and 240 or 160
        local function triangle(p1,p2,p3,u1,v1,u2,v2,u3,v3)
            DrawSpritePoly(p1.x,p1.y,p1.z,p2.x,p2.y,p2.z,p3.x,p3.y,p3.z,
                r,g,blue,alpha,TXD,p.kind,u1,v1,1.,u2,v2,1.,u3,v3,1.)
        end
        local wetDecal=false
        if not foam then
            wetDecal=p.decal and IsDecalAlive(p.decal)
            local now=GetGameTimer()
            if not wetDecal and (not p.decalAt or now-p.decalAt>1000) then
                local center=GetOffsetFromEntityInWorldCoords(vehicle,p.x,p.y,p.z)
                local normalTip=GetOffsetFromEntityInWorldCoords(vehicle,p.x+n.x,p.y+n.y,p.z+n.z)
                local sideTip=GetOffsetFromEntityInWorldCoords(vehicle,p.x+u.x,p.y+u.y,p.z+u.z)
                p.decal=AddDecal(1040,center.x,center.y,center.z,
                    center.x-normalTip.x,center.y-normalTip.y,center.z-normalTip.z,
                    sideTip.x-center.x,sideTip.y-center.y,sideTip.z-center.z,
                    half*2,half*2,1.,1.,1.,1.,30000.,true,true,true)
                p.decalAt=now
                wetDecal=p.decal and p.decal~=0 and IsDecalAlive(p.decal)
            end
        end
        -- Prefer GTA's own water splatter on the paint; textured highlights are
        -- retained only when the engine cannot place a dynamic water decal.
        if not wetDecal then
            triangle(a,b,d,0,0,1,0,1,1)
            triangle(a,d,e,0,0,1,1,0,1)
            triangle(d,b,a,1,1,1,0,0,0)
            triangle(e,d,a,0,1,1,1,0,0)
        end
    end
end
