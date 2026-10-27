# Mission Row configuration (v3)

Camera, radio kit and a physical document printer are configured for the default Mission Row area. Refer to crimson_doj/config.lua for exact coordinates/grade/job allowlists. Custom MLOs require adjustment.

Printer: (441.4,-982.2,30.7), radius 2m. Press E near the printer and select a saved document, or print from an open document in MDT. Register crimson_document from INSTALL/ox_inventory-items.lua first.

v3 also selects Renewed-Banking, qbx_prison and screencapture. Read INSTALL_AR.md before starting: SQL import, inventory definitions and dependency installation are required. Preserving an old config without merging new fields leaves those features disabled. No live world-position validation was performed here.
