# Crimson 3.0 integration status

| Feature | Implemented | Setup / remaining limits |
|---|---|---|
| Police/DOJ/EMS/Business | Department UI, scoped records, staff/jobs, reports | Configure real jobs/grades; not exact XR-MDT parity |
| Citizen personal bank | Current online / saved offline read-only balance | DOJ/Police managers only; unavailable data is not shown as zero |
| Printer | World interaction, immutable item copy, possession-checked reader | Register crimson_document; adjust printer position |
| Invoice payment | Recipient consent, native Qbox debit, Renewed job credit | Import/install Renewed-Banking; ambiguous outcomes need reconciliation |
| Job finances | Provider balance/history, payment journal | No generic manual society withdrawal/deposit UI |
| Fines | Nearby legal-manager action linked to case, bounded amount | Configured fine account must exist; no automatic debt collection |
| Prison | Native qbx_prison jail/release, bounds, routing/proximity | Install provider/items; review confiscation/job defaults |
| Bodycam | Self-started timed WebM capture, local storage, authorized playback/deletion | Experimental screencapture video; no audio/live remote bodycam view |
| Cameras | Explicit-job native fixed cameras | Configure correct MLO positions |
| Units/GPS | Online status and opt-in location waypoint | No continuous full-map tracker or tracking bands |
| Armory | Whitelisted kits, position/grade/cooldown, partial failure rollback | No return/reclaim, shared-stock or kit editor |
| Documents | Text documents, categories, item snapshots and archive | No full rich-page designer, signature workflow or desktop printer/PDF |
| Dispatch | Manual calls, priority, server position and waypoint | No automatic gunshot/robbery integration or unit assignment |
| Businesses | Company catalog/clients/invoices; DOJ licenses/notes | License expiry is metadata, not automated revocation |
| Audit | Version checks, department logs, financial/custody operation state | Ordinary record mutation/audit are not atomic |

Included implementations still require live FiveM installation/acceptance testing. Third-party providers are open-source dependencies, not Crimson-authored code.
