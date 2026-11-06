# Crimson washer V7 — neutral support wrist

V6's left-hand direction was almost perpendicular to the forearm, producing a
large sideways wrist bend in the user's close-up. V7 uses a diagonal grip:
hand yaw -45 degrees and roll -15 degrees in gun space, with support-palm target
`(0.120, 0.045, 0.065)`. The forearm's roll aligns with the palm normal instead
of concentrating the roll at the wrist. Finger curls retain their prior values.

The imported skeleton measures wrist bends of 8.8 degrees (carry) and 12.5 degrees
(spray), down from roughly 77 degrees in V6 carry. The projected forearm/palm
roll difference is zero. Four curled finger middle joints remain around the
collar, within the existing grip validation bounds.

The right-hand pose, gun attachment, shortened model and muzzle are unchanged.
The compiled-channel test compares V7 with V6 and permits changes only to the
left upper arm, forearm and hand; all other channels remain within 1e-5.

Use the updated root `crimson-mechanic.zip`. The resource already includes binary
`crimson_wash_custom_v7.ycd`, and both carry/spray dictionaries point to V7.
No Blender or CodeWalker conversion is required. Remove old V6 overrides, restart
and reconnect. All previous sound, surface foam and stream-direction fixes remain.

Source: Blender 4.3 / official Sollumz v2.6.0 and the previously supplied real
male freemode skeleton. Binary compilation/reread uses official CodeWalker.Core
commit `485d56bec00262ed7fa472261cce7bbc6202b96e`. XML, editable blend, mannequin
previews and JSON validation results are included. The unchanged gun source is
in the sibling `crimson_wash_animation_v5` directory.

The tests verify skeleton transforms and compiled data. They cannot establish
the final skinning/clothing/contact appearance of the user's actual FiveM ped;
that still requires a live check.
