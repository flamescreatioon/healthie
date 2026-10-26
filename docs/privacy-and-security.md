# Privacy and security

Healthie handles personal health data. The following statements describe what
the app does and does not do with that data.

---

## 1. Nothing leaves the device

In its current state Healthie makes **no network requests at all**. There is:

- no analytics SDK,
- no advertising SDK,
- no crash-reporting SDK,
- no backend, and
- no sync target.

Every reading, note, and goal is written to the local Drift database on the
device and stays there. Nothing health-related is ever uploaded.

If a backend is added later (see [the API contract](api-contract.md)), every
write will go through an outbox table — a local write is durably saved before
it is ever offered to the network.

---

## 2. Local storage

Measurements are stored in an **SQLCipher-encrypted** SQLite database on the
device. The database:

- is encrypted at rest with a 256-bit key unique to each install,
- keeps the key in the platform keystore (Android Keystore, hardware-backed
  where the device supports it; iOS Keychain) — never in the database, never
  in code, never in logs, never synced anywhere,
- never hard-deletes user data (tombstones via `deleted_at`),
- is never hand-edited,
- can be exported by the user at any time (CSV preview today; full JSON/PDF
  export planned).

A legacy plaintext database from an earlier install is re-encrypted in place
on first launch after the upgrade. Key loss means data loss — there is no
recovery path, by design.

Health data is never written to application logs, crash reports, or
notification previews.

---

## 3. What the app does not claim

Healthie does **not** claim compliance with HIPAA, GDPR, or any other
health-data regulation. Determining applicable legal requirements and
implementing the required controls is a separate, pending piece of work (see
[future work](future-enhancements.md)). Do not interpret the presence of
password-like protections, encryption language, or "local-first" design as a
compliance claim.

---

## 4. Safety

Blood-pressure readings are screened against the AHA/ACC 2017 guideline.
Screening is not diagnosis. A single reading cannot establish a condition,
and an average cannot soften an individual reading that is potentially
dangerous:

- Readings above 180 systolic or 120 diastolic prompt re-verification and
  emergency guidance immediately, independently of any chart or trend.
- The app never diagnoses, never recommends treatment, and never suggests
  doubling a missed medication.

---

## 5. Units and fonts

Inter is bundled with the app rather than downloaded at runtime. Even the
typeface does not require a network call.

---

## 6. Permissions (Android)

When Health Connect support is added, it will be gated behind the platform's
permission flow: nothing is read from Health Connect without the user's
explicit grant, and Healthie never writes back to Health Connect.

In its current state the app requests no health permissions.

---

## 7. Export

The user can export their data as a CSV preview at any time. Export is
explicit user action — nothing is sent anywhere. The preview shows exactly
what will be exported before anything leaves the app.
