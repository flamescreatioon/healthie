# Phase 8 — Testing & Done Criteria

Backend (Pest/PHPUnit feature tests, two-user matrix) + client tests
(`flutter-testing` skill) written alongside, not after.

- [ ] Offline write appears instantly, reaches server when online
- [ ] Second device sees record after pull (`sync/changes`)
- [ ] Authz: second user sees/modifies nothing (404 matrix, Phase 3)
- [ ] Concurrent edit converges, no duplication (deterministic tiebreak)
- [ ] Delete propagates; tombstone wins over concurrent edit
- [ ] Batch replay is idempotent (no duplicates)
- [ ] No tokens / passwords / health values in server logs
- [ ] Account deletion clears server data (verified in DB)
- [ ] `php artisan test` green; `flutter analyze` clean, `flutter test` green

Back: [Overview](./00-overview.md).
