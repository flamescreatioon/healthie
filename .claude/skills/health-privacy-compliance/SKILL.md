---
name: health-privacy-compliance
description: Handles the privacy, permission, and regulatory obligations of the Healthie health-tracking app — Health Connect permission justification, the Google Play health apps declaration, the data safety form, privacy policy requirements, data retention and deletion, account deletion, export rights, and the boundaries between a personal tracker and medical advice. This skill should be used whenever work involves adding a permission, writing or changing the privacy policy, adding analytics or crash reporting, changing what data is stored or synced, handling account deletion, or preparing a Play Store submission that involves health data. Use it before shipping any change that touches what data leaves the device or what the user consents to.
---

# Privacy and Compliance

Healthie handles **sensitive personal data**: heart rate, sleep, weight, blood
pressure, mood, and activity. It is a personal tracker for one user, but the
data is protected like medical data in most regimes, and Google Play enforces
health-data rules strictly.

## Is This a Medical Device?

**A personal tracker that records what the user tells it and shows trends is not
a medical device.** Healthie does not diagnose, does not treat, and does not
give clinical guidance.

This is a boundary to design around, not a legal opinion:

- **Do not diagnose.** Never infer "you may have hypertension" from a blood
  pressure reading.
- **Do not give treatment advice.** Not "you should take medication for this".
- **Do not claim to be a medical device** in the Play listing or in the app.
- **Do show thresholds factually, if at all.** "Your blood pressure has been
  above 140/90 on 6 of the last 10 readings" is a fact. "Your blood pressure is
  dangerously high" is a clinical judgement the app is not qualified to make.
- **Include a clear disclaimer** that Healthie is not a medical device and does
  not replace professional advice, shown where readings appear.

The moment the app claims to diagnose or prescribe, it becomes a regulated
medical device with a completely different approval burden. Keep it a tracker.

## Health Connect Permissions

### Request the minimum

Every Health Connect permission requires a justification on Play, and a
permission the app does not use is a reason for rejection. Healthie reads
**steps, heart rate, sleep, and workouts**. It does not write.

- **Do not request `READ_WRITE`.** Request `READ` only.
- **Do not request** history beyond 30 days, background read, activity
  intensity, exercise routes, or location unless the corresponding feature ships.
- **Do not request a permission at launch.** Request it at the moment the user
  wants the feature, with an explanation first. A permission prompt on first
  launch, before the user understands what the app is, gets denied and never
  granted.

### Justifications

For each permission, the justification names the user-facing feature that needs
it. A good justification names the feature and its benefit, in the user's
terms:

> **Steps** — Used to show your daily step count, your step goal, and your step
> trends over time. Healthie does not share your step data with anyone.

Not:

> Needed for functionality.

Keep the justifications in sync with the code. If a permission is declared in the
manifest but no feature uses it, remove the declaration.

### The rationale screen

When a user denies a Health Connect permission, the system shows the app's
rationale screen. It must explain:

1. **What** data is requested, in plain language.
2. **Why** the app wants it — which feature it powers.
3. **That it stays on the device** (or where it goes, if it syncs).

This screen is also a policy artefact. It is one of the few places the user
reads exactly what the app does with their body.

## Google Play Health Declaration

If the app reads Health Connect data, it must complete the **Health apps
declaration** in Play Console. The requirements change; check the current
policy at submission time. At minimum:

- Declare the app as a health app in Play Console.
- Complete the Health permissions declaration with a justification for each
  requested permission.
- The declaration must match the app's actual behaviour. An app that declares
  health functionality but does not use the Health Connect APIs violates policy.
- The app's data safety form must accurately describe the health data
  collection, storage, and sharing.

## Privacy Policy

Required, and must be a **live URL** — not a local file, not a page that 404s.
It must cover:

- **What is collected**: the specific health metrics, and what that means in
  practice (sleep duration, step count, heart rate, weight, meals, mood).
- **Where it goes**: stored on the device by default; if the user signs in,
  it syncs to the app's cloud account. Name the processor.
- **Health Connect data**: that Health Connect data is read, that it is read-only,
  and that Healthie does not write to Health Connect.
- **Account and deletion**: how to delete the account and all server data.
- **Export**: how to export the data.
- **Encryption**: TLS in transit, encryption at rest.
- **No sale of personal data**, and no advertising use.
- **Contact**: a real address for privacy requests.
- **Effective date** and a changelog of updates.

## Data Handling Rules

These are engineering requirements, not policy text.

- **Never log health values.** Not in `print`, not in analytics, not in crash
  reports, not in network debug output. Redact before it leaves the device.
- **Never send health data to analytics.** Analytics tools capture screen
  names, error stacks, and session properties. Screen names must be generic
  (`metrics_detail`), never containing a value. Check what a crash reporter
  captures from a health screen and redact it.
- **Never include health data in a URL.** Deep links and query parameters end up
  in server logs and browser history. Pass record ids, not values.
- **Encrypt in transit.** HTTPS only. Reject plaintext endpoints in release
  builds.
- **Encrypt sensitive values at rest** where the platform supports it — Android
  Keystore-backed encryption for the local database if the threat model calls
  for it.
- **Do not copy health data to the clipboard** without an explicit user action.
- **Screenshots**: Android allows `FLAG_SECURE` to prevent screenshots. Consider
  it for the most sensitive screens on a personal device.
- **Do not include health data in the app's crash breadcrumbs.**

## Retention and Deletion

- **Local data** lives until the user deletes it or uninstalls the app.
- **Server data** must be deletable on demand, and automatically after a defined
  retention period for inactive accounts. State the period in the privacy policy.
- **Account deletion must actually delete.** Verify the cascade removes every
  table. A leftover health record belonging to a deleted account is a serious
  defect.
- **Deleting the app should not silently orphan server data** — say clearly what
  happens to the server copy when the user uninstalls.
- **Backups** must expire on the same schedule as the primary store.

## Export

The right to export is both a legal requirement in several regimes and a
practical necessity for a personal health record. Export must work **offline**,
straight from the local database, and produce a readable format (JSON and CSV)
that includes the schema version so it can be re-imported.

## Consent

- **Explicit opt-in** for cloud sync. Healthie works fully locally; sync is
  opt-in, and the choice is visible in settings.
- **Explicit consent** before any health permission prompt.
- **No pre-ticked boxes**, no dark patterns, no consent bundled into account
  creation.
- **Consent for data sharing** must be separate from consent to collect. If the
  app ever shares data with a third party, that needs its own explicit consent.

## GDPR and PIPL Considerations

If the app is used in the EU or China, the applicable regimes apply to the
cloud account and its data. Practical implications:

- A lawful basis for processing health data (explicit consent is the workable
  one for a personal tracker).
- A data-processing agreement with the backend processor (Supabase offers one).
- Records of processing activities.
- The right to access, correct, export, and delete.
- Data residency — where the server stores the data. Say so in the privacy
  policy.

## Pre-Ship Checklist

- [ ] Every declared permission has a corresponding shipped feature.
- [ ] Only `READ` Health Connect permissions are declared; no `WRITE_*`.
- [ ] The rationale screen explains each permission in plain language.
- [ ] The privacy policy is live and covers every point above.
- [ ] The data safety form is accurate.
- [ ] The health apps declaration is complete.
- [ ] No health values appear in logs, analytics, crash reports, or URLs.
- [ ] The account-deletion path removes all server data, verified in the
      database.
- [ ] Export works offline and round-trips.
- [ ] The medical disclaimer appears where readings are shown.
- [ ] Retention periods are implemented and documented.
- [ ] Sync is opt-in, and opting out does not delete local data.
