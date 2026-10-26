# Future enhancements

A prioritised list of work that is honestly not in the current build, with
the reason each item matters.

---

## High priority

| Item | Why |
|---|---|
| **Local notifications for reminders** | Reminder schedules are stored and displayed, but nothing is scheduled with the OS. A reminder that does not notify is not a reminder. Needs `flutter_local_notifications` and platform permission handling. |
| **Cloud sync / backend** | The outbox and data model are built, but there is no server. Implement [`docs/api-contract.md`](api-contract.md) and drain the outbox when connectivity and auth allow. |
| **CSV export to file** | The CSV is rendered in a preview dialog today; writing it to the Documents directory and offering a share sheet is the missing step. |
| **PDF export** | The button explains that it is planned. A printable, doctor-readable clinical summary is the main reason a user exports data. |
| **Android Health Connect import** | Steps, heart rate, sleep, and workouts from the platform as a second source, behind the permission flow. Never write manual entries back to Health Connect. |

---

## Medium priority

| Item | Why |
|---|---|
| **Signed Android release** | Signing config, app bundle, Play Store submission, and the health apps declaration (see [privacy-and-security.md](privacy-and-security.md) — no compliance claim is made yet). |
| **Account creation & multi-user** | The schema already has a `userId` column; the app is currently single-user local-first. |
| **More measurement types** | Heart rate, SpO₂, body temperature, blood glucose entry forms follow the same pattern as blood pressure and weight. |
| **Medication tracking** | Name, dosage instructions, schedule, taken/skipped/missed status, adherence history — with no prescribing or dosage advice. |
| **Export to PDF** (with charts) | A physician-ready clinical summary. |

---

## Low priority

| Item | Why |
|---|---|
| **App icons and splash screen** | Placeholder Flutter assets today. |
| **Dark mode toggle** | System theme is honoured; a manual override is cosmetic. |
| **Cross-metric comparison charts** | Weight vs blood pressure on aligned timelines — useful but not core to daily tracking. |
| **Forecasting** | Explicitly out of scope: the app never predicts a future weight as though guaranteed. If done, it must show uncertainty and label the estimate. |

---

## Out of scope, by design

- **No machine-learning diagnoses.** Insights are strictly descriptive and
  statistical.
- **No "you should lose weight" guidance.** Weight goals are optional,
  user-defined, and never prescriptive.
- **No writing back to Health Connect** from manual entries — that would
  create duplicate data in the user's Health app.
- **No analytics or advertising SDKs.** Health data never leaves the device
  in the current build.
