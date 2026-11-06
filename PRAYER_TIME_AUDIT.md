# Prayer-time source and validation audit

## Source and trust

- Primary source: [Bang-Kurdistan prayer-time dataset](https://raw.githubusercontent.com/Bang-Kurdistan/kurdistan-prayer-times/main/data/).
- Public project page: https://bang-kurdistan.github.io/
- Data is a third-party city timetable. It is not represented as government-certified.
- Tables are fetched on demand and cached only after validation; they are not bundled in the app.
- The upstream README describes the project as open source, but the upstream `LICENSE` currently contains unresolved merge-conflict markers around the copyright notice. This app therefore does not assert a specific upstream data license. Upstream clarification is still needed.
- The app identifies the source in Settings and retains the source filename, city ID, raw time values, and remote/cache/calculated source on each normalized schedule.

## Remote repository verification

The GitHub data directory returned HTTP 200 and contained these 36 JSON filenames:

`Akre.json`, `Amedi.json`, `Arbat.json`, `Barznja.json`, `Bazyan.json`, `Chamchamal.json`, `Chwarta.json`, `Darbandixan.json`, `Duhok.json`, `Dukan.json`, `HajiAwa.json`, `Halabja.json`, `HalabjaN.json`, `Hawler.json`, `Kalar.json`, `Kfri.json`, `Kirkuk.json`, `Koya.json`, `Penjuin.json`, `Piramagrun.json`, `QadirKaram.json`, `Qaladze.json`, `Qaradax.json`, `Ranya.json`, `SaidSadiq.json`, `Slemany.json`, `Soran.json`, `Takya.json`, `TaqTaq.json`, `Tasluja.json`, `Xalakan.json`, `Xanaqin.json`, `Zaxo.json`, `mosul.json`, `qasre.json`, `tuzxurmatu.json`.

All filenames are explicitly mapped to city IDs. Kalar maps to `Kalar.json`. The app's Shaqlawa entry has no matching upstream JSON and is left unavailable rather than redirected to a different city's data.

Each file was fetched and checked for HTTP success, JSON shape, date validity and uniqueness, six required fields, parseable times, normalized prayer ordering, and the 366 MM-DD keys in leap year 2024. The live audit found 33 of 36 files valid under these checks:

| File | Result |
|---|---|
| `Arbat.json` | Rejected: 733 rows with duplicate dates; not used as a schedule. |
| `qasre.json` | Rejected: `Fajr` is malformed (`05,11`) on `11-10`. |
| `tuzxurmatu.json` | Rejected: duplicate `02-01` and missing `02-29`. |

These are source-data problems, not silently corrected values. A previously downloaded cache is accepted only if it passes the same full validation. If neither source nor cache is valid, the UI shows an unavailable state.

## Kalar live reference

`Kalar.json` returned HTTP 200 with 366 rows. The live `11-05` entry was:

| Field | Raw source | Normalized local time |
|---|---:|---:|
| Fajr | `05:03` | `05:03` |
| Sunrise | `06:28` | `06:28` |
| Dhuhr | `11:47` | `11:47` |
| Asr | `02:41` | `14:41` |
| Maghrib | `05:04` | `17:04` |
| Isha | `06:18` | `18:18` |

The production parser retains each raw value alongside its normalized value. The automated test uses the same reference values.

## Parser and timezone rules

- Dataset dates are strictly `MM-DD`; month and day are checked independently and round-tripped against a leap-year calendar.
- Time strings must be `H:mm` or `HH:mm` with valid hour/minute ranges.
- Fajr and Sunrise remain morning values. Dhuhr is unchanged.
- Asr, Maghrib, and Isha receive 12 hours only when the parsed hour is below 12. Already normalized 24-hour values are unchanged.
- Timetable strings are wall-clock times, not UTC timestamps. The parser does not apply the Baghdad UTC offset to them.
- Schedules are constructed in `Asia/Baghdad`; the timezone offset is used for instants/countdowns, not added to source values.
- A single `PrayerSchedule` representation feeds the Home screen, calendar, countdown, and prayer list. The shared next-prayer selector handles the midnight transition.
- Calculated Muslim World League times are only available after the user enables the explicitly labelled fallback setting.

## Tests and remaining uncertainties

Executed successfully:

- `flutter analyze` — no issues.
- `flutter test` — all 17 tests passed, including Kalar `11-05`, `01-01`, `12-31`, leap day, all six fields, malformed/missing values, 12-to-24-hour parsing, already-normalized inputs, filename mappings, city identity/switching, validated-cache fallback, invalid-cache rejection, explicit calculated fallback, Baghdad timezone, and next-prayer midnight handling.
- Live upstream audit — 36 filenames fetched; 33 valid, 3 rejected as listed above. Kalar's live HTTP response and row were checked separately.
- `flutter build web --release` — succeeded.

Automated coverage verifies the common next-prayer selector used by the app. This repository does not contain notification scheduling or home-screen widget integrations, so those integrations cannot be claimed as verified. Other remaining uncertainties are the three upstream data defects, the absent Shaqlawa source file, and the unresolved upstream license notice.
