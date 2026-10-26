# Phase 7 — Deletion, Export, Retention (+ Privacy & Play gates)

## Deletion / export / retention

1. `DELETE /api/v1/account` (auth + password confirm): `forceDelete` user;
   FK `cascadeOnDelete` removes health rows. Feature-test the cascade —
   a leftover row is a privacy defect. Client then clears local DB + signs out.
2. `GET /api/v1/exports/measurements?from&to&metric_type` → queued export job,
   returns export reference; download via signed URL; payload = same shape as
   offline Drift export (JSON + CSV + schema version).
3. Inactive-account retention period defined, implemented (scheduled command),
   stated in privacy policy; backups expire on the same schedule.
4. Document uninstall story: what happens to the server copy.

## Privacy, policy & Play gates (from `health-privacy-compliance`)

- Privacy policy live URL: what is collected; where it goes (device default;
  **this Laravel backend named as processor with region** on sync opt-in);
  Health Connect read-only; account deletion; export; TLS + at-rest encryption
  (managed Postgres + encrypted disks); no sale / no ads; contact; effective
  date + changelog.
- Data handling audit: no health values in Laravel logs, Telescope, Horizon,
  crash breadcrumbs, analytics, URLs (record IDs, never values; generic screen
  names like `metrics_detail`), or clipboard; `FLAG_SECURE` considered.
- Play: health apps declaration + per-permission justification matching actual
  `READ`-only manifests; data safety form accurate; in-app rationale screen;
  medical disclaimer where readings appear.
- Sync opt-in explicit, separate from account creation; opting out never
  deletes local data.

Next: [Testing & done criteria](./08-testing-done-criteria.md).
