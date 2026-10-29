# Crimson 3.2.1 — DOJ ID card and menu placement

Back up the resource/config/recordings and overlay the COMPLETE ZIP. Preserve existing local sound assets and bank settings. Restart crimson_doj. No new SQL changes relative to 3.2.0; installations from older versions still need the complete bundled schema.sql for chief-issued badge registration.

## ID presentation

The held prop is now prop_cs_swipe_card with mp_common/givetake1_a, upper-body secondary hold-last-frame flags (50), instead of the FIB badge prop/pose. This uses native game assets with no emote-menu dependency. The physical generic card is not a custom streamed/texture-replaced model. The NUI credential is redesigned as a horizontal DOJ identification card, with a new bundled justice/scales shield SVG, issuer-chosen name, current rank and credential number. No character portrait is fabricated. The original Crimson RP logo in the MDT sidebar remains unchanged.

Chief-only database-backed issuance, character binding, audience radius/routing isolation, Backspace hiding, token validation, cleanup/cancellation and the eight-second display expiry remain intact. Existing issued cards do not need reissue for this display update.

## All-grade pages

Vehicle search is under OPERATIONS, and Businesses under ADMINISTRATION. These pages appear for every configured DOJ grade with vehicles_view/business_view, including grade zero. Their server RPCs and company-finance view are deliberately exempted from the grade-10 Management gate. Mutations retain the supplied per-grade permissions. Businesses remain DOJ-only; police keep their existing vehicle-search access, and mechanics still cannot enter MDT.

Employees, own job Bank account, Payments log, roster and other Management items still use the previous grade-10 gate. Chief issuance remains 13+. The uploaded rank grants remain unchanged.

## Validation

Full local suite passed: 320 server authorization checks (including both pages at all 15 DOJ grades), 85 DOM checks (category placement, student visibility and new DOJ logo), 57 financial/service checks (including student company-finance inspection and continued own-treasury denial), existing media/client/badge checks, and native ID-card prop/animation argument assertions. SVG XML parsed. Headless Chromium screenshot attempts timed out in this environment; no screenshot-based visual acceptance is claimed. Actual held-card positioning and native pose must be checked inside FiveM. No production balances or records were changed.
