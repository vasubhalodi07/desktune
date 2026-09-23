# DeskTune

An Apple StandBy-style desk mode for Android: a big clock beside a liquid-glass
now-playing card that controls Amazon Music, Spotify and any other media player.
Includes a red night mode for dark rooms.

## Build

```sh
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Release
signing uses `android/app/release.keystore` (not committed).

## First run: enabling media access

DeskTune reads track info and controls playback through Android's
**Notification access**. If you install the APK from a file manager instead of
the Play Store or `adb install`, Android 13+ greys the toggle out
("Restricted setting"). The permission screen detects this and shows the fix:

1. App info → ⋮ (top right) → **Allow restricted settings**
2. Back in DeskTune, tap **Enable Media Access** and switch it on.

## Layout

- `lib/features/desk_mode/` – clock, music card, sliders, night mode
- `lib/features/permission/` – permission gate and restricted-settings guide
- `lib/services/` – Dart side of the native channels (media, battery, settings)
- `android/app/src/main/kotlin/` – media session, volume and battery bridges
