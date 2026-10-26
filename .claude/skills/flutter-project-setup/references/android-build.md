# Android Build Configuration (Healthie)

## Gradle and SDK Versions

Let the Flutter template set AGP, Gradle, and Kotlin. They are coupled to the
Flutter Gradle plugin and mismatched versions produce errors that look like
dependency problems but are not.

The only SDK values Healthie pins deliberately:

```kotlin
android {
    namespace = "com.healthie.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.healthie.app"
        minSdk = 28          // Health Connect requires Android 9 (Pie)
        targetSdk = 35
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")  // replace before release
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}
```

`minSdk = 28` is a hard floor from Health Connect, not a preference.

## Health Connect Manifest Block

This is the part most likely to be gotten wrong. Place it in
`android/app/src/main/AndroidManifest.xml`, inside the `<manifest>` element but
outside `<application>`.

### `<queries>` — required so the app can see Health Connect

```xml
<queries>
    <package android:name="com.google.android.apps.healthdata" />
    <intent>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent>
</queries>
```

Without this, package-visibility filtering on Android 11+ hides Health Connect and
availability checks fail with "not available" even on devices where it works.

### Permissions — only declare the ones actually used

```xml
<uses-permission android:name="android.permission.health.READ_STEPS" />
<uses-permission android:name="android.permission.health.READ_HEART_RATE" />
<uses-permission android:name="android.permission.health.READ_SLEEP" />
<uses-permission android:name="android.permission.health.READ_EXERCISE" />
```

Healthie reads health data; it does not write to Health Connect, so no `WRITE_*`
health permissions are declared.

### Permissions rationale — required

Health Connect launches the app's rationale screen when the user denies a
permission, to explain why the app wanted it. Without this declaration the denial
is silent and the user never learns what was requested.

The `health` package documents this as an intent filter on `MainActivity` itself
rather than a separate rationale activity:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>

    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- Intention to show Permissions screen for Health Connect API -->
    <intent-filter>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent-filter>
</activity>
```

**`MainActivity` must extend `FlutterFragmentActivity`, not `FlutterActivity`.**
On Android 14+ the Health Connect rationale flow casts the host activity to
`ComponentActivity`; `FlutterActivity` is not one, so the cast fails and the
rationale screen crashes the moment a user denies a permission. This is the most
common Health Connect integration failure and it does not reproduce at startup.

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

### Health Connect library

```gradle
dependencies {
    implementation "androidx.health.connect:connect-client:1.1.0"
}
```

The Flutter `health` package (13.3.2) already depends on this transitively;
declaring it explicitly keeps the version aligned with the plugin.

## Health Connect Availability on Older Android

- **Android 14+**: Health Connect is part of the platform.
- **Android 13 and below**: Health Connect ships as a separate installable app
  (`com.google.android.apps.healthdata`).

The app must handle "Health Connect not installed" as a first-class state — offer an
install link rather than showing an error. This is handled in the
`health-connect-android` skill.

## ProGuard / R8

The `health` plugin and Flutter's embedding can be stripped by R8 in release builds.
If Health Connect calls fail only in release:

```proguard
# proguard-rules.pro
-keep class cachet.plugins.health.** { *; }
-keep class androidx.health.** { *; }
-dontwarn androidx.health.**
```

Keep Flutter's own rules intact. Verify release behaviour with
`flutter build appbundle --release` and an actual install — minification bugs do not
reproduce in debug builds.

## Manifest Merge Failures

`Manifest merger failed : uses-sdk:minSdkVersion 26 cannot be smaller than version 28`
means a plugin requires a higher floor than the app declares. Raise `minSdk` to 28
rather than forcing the merge with `tools:overrideLibrary`.

`Attribute application@allowBackup` conflicts and similar: set the attribute on the
`<application>` tag in the app manifest rather than in plugin manifests.

## Build Commands

```
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Always keep `--split-debug-info` output for release builds. Without it, a crash in
production cannot be de-obfuscated.
