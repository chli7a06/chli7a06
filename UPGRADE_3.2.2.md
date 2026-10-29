# Crimson 3.2.2 — exact /e idcard and pending-only printer menu

Back up resource/config/recordings, overlay the COMPLETE ZIP and restart crimson_doj. No new SQL migration or inventory-item changes relative to 3.2.1. Preserve existing sound files, bank selection and local positions.

## Badge emote

The holder now runs the exact client command `e idcard` from the server's installed emote menu. There is no native-animation substitute and no custom prop spawned by Crimson. Backspace, expiry, job/duty change and shutdown run `e c` only when Crimson started the holder's emote. Viewers do not animate or cancel their own emotes; stale presentation hides do not cancel a newer presentation. Existing audience, chief issuance, card appearance and credential binding remain unchanged.

Config.BadgeEmote.command defaults to 'e idcard', cancel to 'e c'. Defaults fill these settings in retained config files. Your emote resource must supply those commands; this release does not include or rename that resource.

## Printer menu

ox_target opens the server's printerDocuments list, returning only document records in the authorized department scope that have no row in crimson_mdt_prints. Thus previously successful print history also hides those documents immediately after upgrade. Filtering is performed before LIMIT 30, so older pending documents remain reachable. Printer allowlist, duty/write access and proximity are checked server-side.

Successful print copies remain in inventory and source records remain in MDT. Failed item issuance already removes its temporary print row and leaves the document eligible. No record is deleted or archived merely because it was printed. This filter is shared by the department, not just one player's local menu, and checks any previous printed revision. Reopening the printer fetches the updated queue. Explicit Print inventory copy from MDT remains available for intentional duplicate copies; hiding a queue entry is not a permanent server prohibition on copying.

## Validation

Full local suite passed: 324 server authorization checks, 85 DOM checks, exact emote command/cancel/Backspace/stale-token tests, existing financial/media/target checks. Twenty isolated real MariaDB checks include the actual printer query against historical printed records, cross-department isolation, temporary failed-copy cleanup, successful queue removal and preservation of MDT records. No production DB or item state was touched. In-server emote menu execution still needs live acceptance.
