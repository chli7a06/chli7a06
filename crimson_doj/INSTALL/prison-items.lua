-- Only merge entries that DO NOT already exist in ox_inventory/data/items.lua.
-- qbx_prison's prison-break zones expect these definitions to exist.
return {
 ['electronickit'] = { label='Electronic kit', weight=1000, stack=true, close=true },
 ['gatecrack'] = { label='Gate cracking tool', weight=1000, stack=true, close=true },
}
