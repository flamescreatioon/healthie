# Phase 4 — Manual Entry (Next.js PWA, Web Primary Input)

Source spec: `health-manual-entry`. Stack: `react-hook-form` + `zod`.

## Goal

The installed PWA ships manual entry only, fast offline. Same speed, same explicit-time, same never-lose-input rules as mobile, in web forms.

## Steps

1. One shared form toolkit (same anatomy as mobile: metric selector → value + visible unit → time defaulting to now → ≤3 optional context fields → one primary save): numeric field, unit toggle, date-time picker, save button with double-submit guard.
2. Hardening: `Intl.NumberFormat` locale-aware parsing (accept decimal-comma input), per-metric precision from the catalog, `inputMode="decimal"` on value fields, thousands separators accepted on input but never stored.
3. Store canonically, convert at the boundary. The unit toggle converts the current value in place — never reinterpret the number under a new label.
4. Validation with zod + the catalog ranges: on blur (non-blocking) and on submit (hard stop with a specific message + focus, e.g. "Enter a weight between 20 and 400 kg"). Reject out-of-range input; never silently clamp or round without telling the user.
5. Editing preserves `recordedAt` unless the user explicitly changed the time. Deletion is soft with an undo toast, synced as a tombstone. All of this works offline in the installed PWA and syncs later.
6. Accessibility: real `<label>`s (not placeholders), unit announced with value, validation errors in `aria-describedby`/`aria-live`, full keyboard flow, targets ≥ 48px, failed saves keep all input.

## Exit criteria

- [ ] Logging works with zero permissions of any kind, including fully offline in the installed PWA.
- [ ] Canonical-unit round-trips verified both directions.
- [ ] Decimal-comma locale parses correctly.
- [ ] Out-of-range input rejected with a specific message, input preserved.
- [ ] Double-submit creates one record.
- [ ] Edit preserves timestamp; delete is undoable and syncs as tombstone.
