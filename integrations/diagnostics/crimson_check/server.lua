-- Read-only installation diagnosis. No database, permissions or resource files are modified.
local function inspect()
 local resource='crimson_doj'
 local path=GetResourcePath(resource)
 print('========== CRIMSON INSTALL CHECK ==========')
 print('PATH: '..tostring(path))
 print('STATE: '..tostring(GetResourceState(resource)))
 print('CACHED VERSION: '..tostring(GetResourceMetadata(resource,'version',0)))
 local manifest=LoadResourceFile(resource,'fxmanifest.lua')
 if not manifest then print('MANIFEST: missing/unreadable');print('========== END CRIMSON CHECK ==========');return end
 print('DISK VERSION: '..tostring(manifest:match("version%s+['\"]([^'\"]+)")))
 local registry=manifest:find('server_registry.lua',1,true)
 local main=manifest:find("['\"]server%.lua['\"]")
 print('REGISTRY IN MANIFEST: '..tostring(registry~=nil))
 print('REGISTRY BEFORE SERVER: '..tostring(registry~=nil and main~=nil and registry<main))
 print('OLD OPERATIONS IN MANIFEST: '..tostring(manifest:find('client_operations.lua',1,true)~=nil))
 local code=LoadResourceFile(resource,'server_registry.lua')
 print('REGISTRY FILE EXISTS: '..tostring(code~=nil))
 print('REGISTRY FUNCTION EXISTS: '..tostring(code~=nil and code:find('function CrimsonRegistry',1,true)~=nil))
 print('EXTRA .TXT MANIFEST: '..tostring(LoadResourceFile(resource,'fxmanifest.lua.txt')~=nil))
 print('========== END CRIMSON CHECK ==========')
end
RegisterCommand('crimsoncheck',function(source)if source==0 then inspect()end end,true)
inspect()
