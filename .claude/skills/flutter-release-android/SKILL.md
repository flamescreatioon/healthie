---
name: flutter-release-android
description: Prepares, builds, signs, and ships the Healthie Android app to Google Play — keystore and signing configuration, version code management, app bundle builds, R8 and ProGuard rules, obfuscation and symbol handling, CI release pipelines, and the Play Console submission checklist including the health apps declaration. This skill should be used whenever work involves preparing a release, bumping versions, configuring signing, building an app bundle or APK, setting up CI, or submitting to the Play Store. Use it before the first release build.
---

# Android Release and Publishing

## Signing

Android releases need two keys, and confusing them causes a permanent problem
that cannot be fixed by changing a file.

| Key | Purpose | Loss consequences |
|---|---|---|
| **Upload key** | Signs the AAB uploaded to Play. | You can ask Google to reset it (identity verification, days). |
| **App signing key** | Google holds it; Play re-signs the distributed APK. | You can request a transfer to your own key. |

Keep the upload key under your control. Losing it means a multi-day reset
process; losing the app signing key is worse, because the apps already installed
by users cannot be updated by a differently-signed build.

### Configuration

Create `android/key.properties` — **never commit this file**:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

In `android/app/build.gradle.kts`:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("upload") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
            ...
        }
    }
}
```

**Guard against a debug-signed release.** The Flutter template ships with
`signingConfig = signingConfigs.getByName("debug")` in the release block, which
produces a build that installs fine but cannot be updated on the Play Store.
Failing to replace it is the single most common release mistake.

### Keep the keystore safe

- Store the keystore in a password manager or a secure secret store, with a
  backup that is verified recoverable.
- **Never commit it.** Add to `.gitignore`: `*.jks`, `*.keystore`,
  `android/key.properties`.
- Never upload it to CI artifact storage in plaintext. Store it as a CI secret
  and reconstruct it in the workflow.
- Record the key's alias, password, and file location in the project's secure
  documentation — not in a public README.

## Version Management

`versionCode` is an integer that must **increase** with every upload to Play.
`versionName` is the user-visible version string.

```yaml
# pubspec.yaml
version: 1.0.0+1
```

The part after `+` is `versionCode`. `1.0.0+2` → `1.0.1+3`. Play rejects an
upload whose version code has not increased.

Use a consistent scheme: `major.minor.patch+buildNumber`, where the build
number is a monotonic integer. Deriving the build number from CI (`github.run_number`)
is a reliable way to guarantee monotonicity.

## Building

```bash
# Release APK (sideload / internal testing)
flutter build apk --release

# Release app bundle (what Play requires for new apps)
flutter build appbundle --release

# Obfuscated, with symbols kept for de-obfuscating crash reports
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/appbundle-release.symbols
```

**Always keep the `--split-debug-info` output.** It is what makes an obfuscated
production stack trace readable. Upload it to the crash reporter at build time
rather than hoping to find it later.

### R8 and ProGuard

`minifyEnabled = true` and `shrinkResources = true` are already set in the
release build type. R8 strips code the app needs at runtime, which produces
crashes that never reproduce in debug.

Keep rules required by this project's plugins:

```proguard
# proguard-rules.pro

# Health Connect plugin
-keep class cachet.plugins.health.** { *; }
-keep class androidx.health.** { *; }
-dontwarn androidx.health.**

# Drift / SQLite
-keep class dev.schollz.** { *; }
-keepclassmembers class * extends androidx.room.** { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**
```

Flutter's own rules come from `getDefaultProguardFile("proguard-android-optimize.txt")`
— do not remove that line.

**A release-only crash is usually R8.** If the app crashes only in a release
build, add a keep rule before investigating anything else.

## CI Release Pipeline

A GitHub Actions workflow that builds and publishes:

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.47'
          channel: stable
          cache: true

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test

      # Reconstruct the keystore from secrets.
      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=upload
          storeFile=../upload-keystore.jks
          EOF

      - run: flutter build appbundle --release --obfuscate --split-debug-info=build/symbols

      - uses: actions/upload-artifact@v4
        with:
          name: appbundle
          path: build/app/outputs/bundle/release/app-release.aab

      - uses: ncipollo/release-action@v1
        with:
          artifact: build/app/outputs/bundle/release/app-release.aab
          track: internal
          packageName: com.healthie.app
          serviceAccountJsonSecret: ${{ secrets.PLAY_SERVICE_ACCOUNT }}
```

The workflow must **build before signing artefacts** and must **not fail the
build on signing** — the AAB is useful even if the Play upload fails.

## Play Console Submission Checklist

Technical:

- [ ] `versionCode` is higher than the last upload.
- [ ] `applicationId` matches the Play listing exactly.
- [ ] The AAB was built with the upload key, not the debug key.
- [ ] `minSdk` is 28 and `targetSdk` meets the current Play requirement.
- [ ] ProGuard keep rules are in place and the release build was smoke-tested.
- [ ] The app icon and feature graphic are uploaded (512×512 PNG icon, 1024×500
      feature graphic).
- [ ] A release APK was installed and smoke-tested on a real device — not just
      built.

Policy (see the `health-privacy-compliance` skill for detail):

- [ ] The **Health apps declaration** is completed in Play Console.
- [ ] Every requested Health Connect permission has a justification.
- [ ] The privacy policy URL is live and describes the health data handling.
- [ ] The data safety form is filled in accurately — it is a legal attestation.
- [ ] Account deletion is available in-app and in the Play listing (Google
      requires a web account-deletion URL for apps that allow account creation).

## Release Checklist

Before promoting to production:

1. `flutter analyze` — clean.
2. `flutter test` — all green.
3. Integration smoke test on a physical device.
4. Release build installed and manually exercised — log a value, grant and deny
   Health Connect permissions, sync, and restart the app.
5. Version code bumped.
6. Changelog written.
7. Uploaded to the **internal** track first.
8. Internal testers confirm it works on their real devices.
9. Promote to closed/open/production.

Use **staged rollout** for production (1% → 10% → 50% → 100%) and watch the
crash rate between stages. Health data bugs often appear only on particular
devices or OS versions.

## Rollback

Play cannot un-publish a rollout instantly, and a bad build cannot be
un-installed from users' devices. The mitigations:

- Staged rollout keeps the blast radius small.
- A rollback means shipping a new build with a higher version code — so a
  rollback path must exist and be tested before it is needed.
- Keep the previous AAB and its symbols so a crash in the new build can be
  diagnosed and a fix shipped quickly.
