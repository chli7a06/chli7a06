# Dependency provenance and source

Crimson code is independent. The other resource folders are third-party open-source resources with their original LICENSE/attribution retained. They are distributed separately as an aggregate, not claimed as Crimson-authored.

- screencapture 0.17.2: official built release, https://github.com/itschip/screencapture/tree/8fb1021330052eba49c9f9378026bd76203edc21 ; corresponding source archive included. Video API is experimental and video-only. No Cloudflare/live-stream service is configured.
- Renewed-Banking 2.1.4: official built release, https://github.com/Renewed-Scripts/Renewed-Banking ; v2.1.4 source archive included. Runtime Lua source is also included in the resource; upstream release assets can include updates beyond the source tag. Native Qbox and exports used by Crimson were verified present in the downloaded release.
- ox_target 1.18.1: official built release, https://github.com/overextended/ox_target/tree/v1.18.1 ; source archive included.
- qbx_prison 1.0.0: unmodified Lua source at https://github.com/Qbox-project/qbx_prison/tree/977634bbaf1757dba3e6d95f0b7dd3be693e11ae . Review default inventory confiscation/job changes and ensure its items exist.

Release ZIPs were fetched from official GitHub endpoints with TLS verification. DEPENDENCY_PROVENANCE.json records their SHA-256 for this distribution; these hashes identify the downloads and are not independently signed attestations. The archive integrity and required built files/API names were checked. FiveM execution of these providers was not performed here.

Keep source_archives as ZIPs for source/build/license reference; do not extract their duplicate resource manifests into your live resources tree. Existing customized dependencies should be preserved, not overwritten blindly.
