# Project status

Updated during the timetable repair and UI redesign.

## Implemented

- Sorani-first RTL Flutter app with light, dark and system themes.
- Shared city-timetable repository, strict validation, source metadata, valid
  per-city offline cache, and unavailable state when no valid table is available.
- Explicitly labelled MWL calculated fallback; disabled by default.
- Compact Home and city selector, monthly calendar, static Qibla bearing,
  Tasbih, four-destination navigation, and grouped Settings.
- Noto Sans Arabic font asset with the SIL Open Font License 1.1.
- Kalar regression coverage, date/time parsing, cache/source selection, city
  mappings, Baghdad timezone, midnight transition and simulated viewport tests.

## Data verification and limits

- The upstream directory returned HTTP 200 and 36 JSON filenames. All filenames
  are mapped to city IDs. Kalar uses `Kalar.json`; Shaqlawa has no matching file.
- Strict checks found 33 valid city files. `Arbat.json` has duplicate dates and
  733 rows; `qasre.json` has malformed `Fajr: "05,11"` on `11-10`;
  `tuzxurmatu.json` duplicates `02-01` and lacks `02-29`.
- These three files are rejected instead of repaired or substituted. A cache is
  used only if it passes the same schema and daily-record validation.
- `Kalar.json` returned 366 rows; `11-05` raw values normalize to Fajr `05:03`,
  Sunrise `06:28`, Dhuhr `11:47`, Asr `14:41`, Maghrib `17:04`, Isha `18:18`.
- Tables are local wall-clock values in `Asia/Baghdad`; the UTC offset is never
  added to the timetable strings.
- Upstream README labels the data open source, but `LICENSE` has unresolved
  merge-conflict markers. The application does not assert a specific upstream
  data license or government certification. Maintainer clarification remains
  necessary.

## Not implemented or not verified

- Arabic and English UI translations/language selection; the current UI is
  Sorani-only. Hijri dates are absent.
- GPS/nearest-city selection and a live magnetic Qibla sensor.
- Notification scheduling, Adhan playback, home-screen widgets, Ramadan tools
  and prayer tracking; these integrations are not present in this repository.
- Native Android/iOS builds or on-device tests. This host has no Android SDK;
  iOS build requires macOS and Xcode.
- The Qibla calculation uses available city-center coordinates; some city
  entries do not have coordinates.

## Verification

- Flutter 3.47.2 stable / Dart 3.13.2.
- `flutter analyze`: no issues.
- `flutter test`: all 17 tests passed.
- `flutter build web --release`: passed.
- Live upstream audit: 36 files fetched; 33 valid under strict checks.
- Widget tests exercised Home and Calendar at logical viewports `320×568`,
  `393×852`, and `768×1024`.
- Debug web server returned HTTP 200. No app registered with the VS Code Dart
  Tooling Daemon, so the hot-restart tool could not connect.
