# Health Connect — Android Setup

Manifest and platform configuration for the `health` package 13.3.2.

## 1. `android/app/build.gradle.kts`

```kotlin
android {
    defaultConfig {
        minSdk = 28          // Health Connect requires Android 9 (Pie)
        targetSdk = 35
        compileSdk = 35
    }
}
```

## 2. `android/gradle.properties`

The plugin requires AndroidX and Jetifier:

```properties
org.gradle.jvmargs=-Xmx1536M
android.enableJetifier=true
android.useAndroidX=true
```

## 3. `AndroidManifest.xml`

### Package visibility — required

Without this, Android 11+ package-visibility filtering hides Health Connect and
every availability check reports "not installed" on devices where it works.

```xml
<!-- Check whether Health Connect is installed or not -->
<queries>
    <package android:name="com.google.android.apps.healthdata" />
    <intent>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent>
</queries>
```

### Permissions rationale — required

Health Connect launches the app's rationale screen when the user denies a
permission, so the user can see what was asked for and why. Without this
declaration, denial is silent and the user never learns what the app wanted.

The plugin's documented approach puts the intent filter on `MainActivity`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">

    <meta-data
        android:name="io.flutter.embedding.android.NormalTheme"
        android:resource="@style/NormalTheme" />

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

### Viewing permission usage

Optional, but recommended — it lets the user audit exactly what the app reads.
It requires an activity alias targeting `MainActivity`:

```xml
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
    <intent-filter>
        <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
        <category android:name="android.intent.action.HEALTH_PERMISSIONS" />
    </intent-filter>
</activity-alias>
```

### Health permissions

Declare only the data types the app actually uses. Healthie reads steps, heart
rate, sleep, and workouts:

```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_EXERCISE"/>
```

No `WRITE_*` permissions — Healthie does not write to Health Connect.

### Conditional permissions

Add these only if the corresponding feature ships:

```xml
<!-- Data older than 30 days -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>

<!-- Background reading -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"/>

<!-- Activity intensity (exercise intensity minutes) -->
<uses-permission android:name="android.permission.health.READ_ACTIVITY_INTENSITY"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVITY_INTENSITY"/>

<!-- Workout GPS routes -->
<uses-permission android:name="android.permission.health.READ_EXERCISE_ROUTE"/>
<uses-permission android:name="android.permission.health.WRITE_EXERCISE_ROUTE"/>

<!-- Steps and heart rate on Android 10+ -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

`ACTIVITY_RECOGNITION` is a **separate runtime permission** required for step
count and heart rate on Android 10+. It is granted at install time on Android 9.
The plugin documentation suggests `permission_handler` for these dangerous-level
permissions:

```dart
await Permission.activityRecognition.request();
```

Location permissions are only needed for workout routes. If the app does not
show maps, do not request location at all — it is a heavy permission to ask for
and reviewers notice.

## 4. `MainActivity` must extend `FlutterFragmentActivity`

On Android 14+, the Health Connect rationale flow casts the host activity to
`ComponentActivity`. Flutter's `FlutterActivity` is not a `ComponentActivity`,
so the cast fails and the rationale screen crashes.

```kotlin
package com.healthie.app

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**This is the single most common Health Connect integration failure.** The symptom
is a crash the moment the user denies a permission — not an error at startup, so
it often escapes notice until manual testing.

## 5. Health Connect availability

- **Android 14+**: Health Connect is part of the platform.
- **Android 13 and below**: Health Connect is a separate installable app
  (`com.google.android.apps.healthdata`). It needs to be installed and it needs
  internet access on first launch.

The `<queries>` block lets the app detect the provider. The plugin's
`configure()` performs the check.

## 6. Gradle dependency

```gradle
dependencies {
    implementation "androidx.health.connect:connect-client:1.1.0"
}
```

The `health` package depends on this transitively; declaring it explicitly keeps
the version aligned with the plugin.

## 7. Verification

Confirm the setup on a **real device** and on an **emulator with a Google APIs
image** (the default AOSP images may not ship Health Connect).

Checklist:

- [ ] The app launches without a Health Connect error.
- [ ] The rationale screen appears when a permission is denied, and does not crash.
- [ ] The rationale screen explains the request in user-facing language.
- [ ] "View permission usage" opens and lists only the requested types.
- [ ] With permissions denied, manual entry still works completely.
- [ ] With Health Connect unavailable, the app degrades to manual entry without
      an error state.
- [ ] `android.permission.ACTIVITY_RECOGNITION` is requested on Android 10+.
- [ ] Reading steps returns a sensible total for a day of use.

## 8. Play Store requirements

- The app must declare itself as a **health app** in the Play Console if it
  reads health data, and complete the **Health permissions declaration**.
- Every requested Health Connect permission needs a justification describing the
  user-facing feature that needs it.
- The privacy policy must state what health data is collected, where it goes, and
  that Health Connect is used.
- If the app is distributed outside Google Play, the Health Connect permissions
  declaration may still be required by Google Play for apps with a Play listing.
  Check the current policy at publish time — the requirements change.

See the `health-privacy-compliance` skill for the full checklist.
