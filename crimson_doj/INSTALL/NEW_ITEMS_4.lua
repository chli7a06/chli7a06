-- Paste these two entries INSIDE your existing return { ... } table.
-- Do not add another return. Skip any item name already registered.
['crimson_tracking_band'] = {
 label='Justice tracking band',weight=200,stack=true,close=true,consume=0,
 client={export='crimson_doj.useTrackingBand'},
},
['crimson_bodycam'] = {
 label='Crimson bodycam',weight=200,stack=false,close=true,consume=0,
 client={export='crimson_doj.useBodycam'},
},
