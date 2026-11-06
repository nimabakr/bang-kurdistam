# بانگ | Kurdistan

Sorani-first, right-to-left prayer-time app for Kurdistan Region cities. Schedules
use validated city-specific tables from
[Bang-Kurdistan/kurdistan-prayer-times](https://github.com/Bang-Kurdistan/kurdistan-prayer-times)
as the primary source. A valid local cache is used offline. Muslim World League
calculation is available only when explicitly enabled in Settings; it is not
silently substituted for missing or invalid city data.

The upstream timetable is third-party data, not government-certified. Its live
files and licensing status were audited; see
[PRAYER_TIME_AUDIT.md](PRAYER_TIME_AUDIT.md). The UI review and known gaps are
recorded in [UI_REDESIGN_REPORT.md](UI_REDESIGN_REPORT.md).

## Run

1. Install Flutter stable (the project currently requires Dart `^3.13.2`).
2. From the project root, run `flutter pub get`.
3. Run `flutter run`.

The Android display name is configured in the manifest. Android application ID
and iOS bundle identifier still need to be replaced with identifiers owned by
the release publisher before distribution.

## Implemented

- Validated, source-aware city timetable parsing, per-city cache, Baghdad local
  wall times, live countdown, and shared schedules for Home and Calendar.
- Explicitly labelled calculated fallback, disabled until enabled in Settings.
- Sorani RTL Home, searchable city sheet and favorites, monthly calendar, Qibla
  bearing, Tasbih, and compact More/Settings navigation.
- Persistent light/dark/system appearance, madhab setting, prayer adjustments,
  Tasbih state and selected city.
- Noto Sans Arabic bundled under the SIL Open Font License 1.1 with the Sorani
  characters ڕ ڵ ۆ ێ ە چ گ ژ.

## Data and limitations

The source directory contains 36 city JSON files. Thirty-three passed strict
record/date/time validation during the live audit. `Arbat.json`, `qasre.json`,
and `tuzxurmatu.json` currently fail validation and are not presented as
authoritative schedules. Shaqlawa has no matching upstream file and remains
unavailable. The app uses `Asia/Baghdad`; source wall times are not shifted by
the UTC offset.

The upstream README describes the dataset as open source, but its `LICENSE`
currently contains unresolved merge-conflict markers around the copyright
notice. The app fetches tables rather than bundling them and does not claim a
specific upstream data license; clarification from the data maintainers is
needed.

City selection is manual and uses available city-center coordinates; GPS and
nearest-city detection are not implemented. Qibla is a geographic bearing, not
a live magnetic compass. This repository has no notification/Adhan engine,
home-screen widgets, Ramadan tools, prayer tracker or Hijri date support.
Arabic and English UI translations are not implemented; the current UI is
Sorani-only.

## Verification

`flutter analyze`, all 17 tests, and `flutter build web --release` passed on the
available Windows Flutter toolchain. Responsive widget tests cover logical
viewports `320×568`, `393×852`, and `768×1024`; they are not physical-device
tests. Android release build validation was blocked because no Android SDK is
installed. iOS builds require macOS and Xcode. A debug web server returned HTTP
200, but the Dart Tooling Daemon did not register the app for hot restart.
