# Crimson 3.2.0 — chief-issued badges, Management 10+, image documents

Back up the full resource, config, recordings and database. Overwrite the COMPLETE resource files, including schema.sql, fxmanifest.lua, permissions.lua, client_badge.lua, server_badge.lua and the web files. Preserve local sound assets and bank/printer settings. Restart crimson_doj. Startup idempotently creates crimson_mdt_badges; no database reset is required. Keep existing printed documents and records.

## Badge issuance and presentation

/dojbadge has been removed. An on-duty DOJ chief at grade 13 or 14 opens Management → Employees → Issue DOJ badge, enters the recipient citizen ID and the name to print. The recipient must be on-duty DOJ and within three metres in the same routing bucket. Issuance adds an owner-bound ox_inventory item and stores the authoritative issuer/name/owner/ticket in SQL. Failure to add the item removes its registry row. Identity, grade and distance are checked again after SQL waits. Chief level is configurable with Config.BadgeChiefMinGrade (default 13).

Existing self-issued / giveitem badges lack the registry ticket and must be reissued by a chief. Do not give unbound inventory copies. Item definitions remain unchanged.

Using the credential shows the database-issued name and current DOJ rank, presents prop_fib_badge using the native paper_1_rcm_alt1-9/player_one_dual-9 animation, and displays the card to the holder and nearby same-bucket viewers. Backspace stops the holder pose and hides the current presentation for its recipients. A viewer's Backspace hides only their local card. Presentation tokens stop an old hide/timeout from dismissing a newer card. The existing eight-second expiry remains; props are cleaned on expiration, job/duty change, logout and resource stop. Delayed animation loads cannot create a prop after dismissal. No emote resource dependency.

## Management access

Management sidebar and its server endpoints require DOJ grade >=10, independent of hidden buttons. Existing granular grants still apply: visibility at grade 10 does not automatically grant employee management or treasury writes. Thus earlier grade 6/9 personnel grants cannot bypass the new Management gate. Grades 10–12 can inspect Employees/Businesses; chief-specific issuance remains 13+. Reports/Citizens remain governed by the supplied per-rank permissions. Police/EMS retain their previous policy. Config.ManagementMinGrade defaults to 10.

## Printable hosted image documents

Upload your own PC image to your hosting provider, then create/edit a Documents record and paste its direct public HTTPS JPG/JPEG/PNG/WebP URL into Document image URL. Save the record, view the image, then use the existing ox_target printer or Print inventory copy while nearby. The printed crimson_document item shows the image plus saved title/text. Existing text-only documents continue to work.

The supplied URL shape is supported:
https://r2.fivemanage.com/VNbtv8wpJdqEafjK3iz8n/LSPD_BCSO_Pistol_Confiscation_Announcement_page-0001.jpg

Config.DocumentImageHosts defaults to r2.fivemanage.com; add other trusted direct-image hosts explicitly if needed. Non-HTTPS, unapproved hosts and non-raster-image paths are refused server-side. Images are created as img DOM elements, not injected HTML. No server-side URL fetching or upload credentials. There is no built-in PC-to-host uploader; choose your file in the hosting provider's uploader and paste the resulting URL. PDFs/local file paths are not supported in this image field.

The print snapshot stores the validated URL, title/text and record revision. It freezes the reference, NOT the external image bytes: changing/removing the hosted image can change/break its appearance in old copies. Keep the hosted file stable/public. The example remote host could not be reached from the development environment (network proxy 403), so actual remote loading must be checked in FiveM.

## Validation

Full local suite passed: 290 server authorization checks, 81 DOM checks, existing financial/media/privacy tests, new chief issuance/database identity/audience/dismissal checks, and badge animation/Backspace/cancellation tests. Real temporary MariaDB schema/migration tests passed with eight tables and idempotent rerun. No production DB, balances or remote resource files were modified. Real FiveM animation appearance, two-player presentation and external image rendering still need in-server acceptance.
