-- Merge this entry INSIDE the returned table in ox_inventory/data/items.lua.
-- Do not replace your entire items.lua. Restart ox_inventory and crimson_doj afterwards.
return {
 ['crimson_document'] = {
  label = 'Crimson document', weight = 10, stack = false, close = true,
  consume = 0, description = 'Official printed Crimson document',
  client = { export = 'crimson_doj.useDocument' },
 },
}
