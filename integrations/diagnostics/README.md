# Read-only resource location check

Extract crimson_check into the running server's resources directory, separately from crimson_doj. In txAdmin run refresh, then ensure crimson_check (one command at a time). The checker prints the actual GetResourcePath, cached/disk manifest versions, registry inclusion/order and file presence. It reads no database and modifies no resource or access settings. It can be stopped/removed after diagnosis. Console-only crimsoncheck prints the same report again.
