# UI redesign report

## Screens and navigation

- Home: compact Bang/city/settings header, Gregorian date, one next-prayer/countdown card, five obligatory prayers, and secondary Sunrise time.
- City selection: searchable bottom sheet with city, governorate, selected state, and favorites.
- Calendar: compact monthly rows sourced from the shared city schedule; missing data is shown as unavailable rather than calculated independently.
- Qibla: large compass-style bearing display and distance, with an unavailable state when coordinates are missing.
- More: Tasbih, prayer times, and Settings.
- Bottom navigation: Home, Calendar, Qibla, More.
- Settings: appearance, city, Asr madhab, explicit calculated fallback, minute adjustments, data handling, and source attribution.

## Visual and typography changes

- Applied an emerald/champagne palette, restrained rounded surfaces, compact spacing, and minimal status/source labels in light and dark themes.
- Removed the long explanatory home and city-picker banners, redundant city/source copy, and the calendar's large explanatory footer.
- Bundled Noto Sans Arabic under the SIL Open Font License 1.1 and applied it as the app font for Sorani glyph coverage. The license text is included at `assets/fonts/OFL.txt`.
- Kept the whole current interface Sorani Kurdish and right-to-left. Arabic and English UI translations/language selection are not implemented yet.

## Responsive and accessibility checks

- Flutter widget tests exercised Home and Calendar at logical viewports `320×568`, `393×852`, and `768×1024`; no layout exceptions were reported.
- Prayer rows expose prayer/time semantics; the Tasbih control has an explicit semantic label; icon controls have tooltips.
- These are simulated Flutter viewports, not physical-device checks. No Android SDK or iOS build environment was available, and assistive-technology testing was not performed.

## Scope and known gaps

- Gregorian date is shown; a Hijri date is not implemented.
- The Qibla indicator is a calculated bearing, not a live magnetic sensor compass.
- This repository does not contain notification, Adhan playback, home-screen widget, GPS, Ramadan, or prayer-tracker implementations; those features were not verified or added as part of this redesign.
- The current interface is Sorani-only despite the requested Kurdish/Arabic/English localization.
- The web release build succeeded. The debug web server returned HTTP 200, but no app registered with the VS Code Dart Tooling Daemon, so the requested hot restart could not be completed.
