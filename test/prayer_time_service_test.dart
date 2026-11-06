import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kurdistan_bang/app_state.dart';
import 'package:kurdistan_bang/domain/city.dart';
import 'package:kurdistan_bang/domain/prayer_schedule.dart';
import 'package:kurdistan_bang/services/baghdad_clock.dart';
import 'package:kurdistan_bang/services/hijri_calendar.dart';
import 'package:kurdistan_bang/services/prayer_time_service.dart';
import 'package:kurdistan_bang/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeBangTimeZones();

  final kalar = cities.firstWhere((city) => city.id == 'kalar');
  final hawler = cities.firstWhere((city) => city.id == 'erbil');

  test('Kalar 11-05 raw times normalize to expected local schedule', () {
    final dataset = _parse(kalar);
    final schedule = dataset.scheduleFor(
      city: kalar,
      date: DateTime(2024, 11, 5),
      madhab: AsrMadhab.shafi,
      minuteAdjustments: const {},
    );

    expect(schedule.cityId, 'kalar');
    expect(schedule.source, PrayerScheduleSource.cityTimetable);
    expect(schedule.sourceReference, 'Kalar.json');
    expect(schedule.times.map((time) => time.id), [
      'fajr',
      'sunrise',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ]);
    expect(schedule.times.map((time) => _clock(time.time)), [
      '05:03',
      '06:28',
      '11:47',
      '14:41',
      '17:04',
      '18:18',
    ]);
    expect(schedule.times.map((time) => time.rawValue), [
      '05:03',
      '06:28',
      '11:47',
      '02:41',
      '05:04',
      '06:18',
    ]);
  });

  test('year boundaries and leap day use MM-DD component validation', () {
    final dataset = _parse(kalar);
    for (final (date, expected) in [
      (DateTime(2024, 1, 1), '01-01'),
      (DateTime(2024, 12, 31), '12-31'),
      (DateTime(2024, 2, 29), '02-29'),
    ]) {
      final schedule = dataset.scheduleFor(
        city: kalar,
        date: date,
        madhab: AsrMadhab.shafi,
        minuteAdjustments: const {},
      );
      expect(schedule.date.month, date.month);
      expect(schedule.date.day, date.day);
      expect(dataset.records.containsKey(expected), isTrue);
    }

    expect(
      () => PrayerTimetableRepository.parseMonthDay('02-29', year: 2023),
      throwsA(isA<TimetableValidationException>()),
    );
    expect(
      PrayerTimetableRepository.parseMonthDay('02-29', year: 2024),
      DateTime.utc(2024, 2, 29),
    );
    expect(
      () => PrayerTimetableRepository.parseMonthDay('13-01', year: 2024),
      throwsA(isA<TimetableValidationException>()),
    );
  });

  test('city file mappings match verified upstream JSON filenames', () {
    const verifiedFiles = {
      'Akre.json',
      'Amedi.json',
      'Arbat.json',
      'Barznja.json',
      'Bazyan.json',
      'Chamchamal.json',
      'Chwarta.json',
      'Darbandixan.json',
      'Duhok.json',
      'Dukan.json',
      'HajiAwa.json',
      'Halabja.json',
      'HalabjaN.json',
      'Hawler.json',
      'Kalar.json',
      'Kfri.json',
      'Kirkuk.json',
      'Koya.json',
      'Penjuin.json',
      'Piramagrun.json',
      'QadirKaram.json',
      'Qaladze.json',
      'Qaradax.json',
      'Ranya.json',
      'SaidSadiq.json',
      'Slemany.json',
      'Soran.json',
      'Takya.json',
      'TaqTaq.json',
      'Tasluja.json',
      'Xalakan.json',
      'Xanaqin.json',
      'Zaxo.json',
      'mosul.json',
      'qasre.json',
      'tuzxurmatu.json',
    };
    expect(
      cities.map((city) => city.timetableFile).whereType<String>().toSet(),
      verifiedFiles,
    );
    expect(
      cities.firstWhere((city) => city.id == 'kalar').timetableFile,
      'Kalar.json',
    );
    expect(
      cities.firstWhere((city) => city.id == 'shaqlawa').timetableFile,
      isNull,
    );
  });

  test('tabular Hijri conversion supports correction and month boundaries', () {
    final firstOfRamadan = HijriDate.fromGregorian(DateTime(2024, 3, 11));
    expect(
      (firstOfRamadan.year, firstOfRamadan.month, firstOfRamadan.day),
      (1445, 9, 1),
    );
    final corrected = HijriDate.fromGregorian(
      DateTime(2024, 3, 11),
      dayAdjustment: -1,
    );
    expect((corrected.month, corrected.day), (8, 29));
    expect(HijriDate.toGregorian(1445, 9, 1), DateTime.utc(2024, 3, 11));
    expect(HijriDate.daysInMonth(1445, 9), 30);
  });

  test(
    'time parsing converts afternoon once and preserves normalized hours',
    () {
      for (final (field, raw, expected) in [
        ('Fajr', '05:03', '05:03'),
        ('Sunrise', '06:28', '06:28'),
        ('Dhuhr', '11:47', '11:47'),
        ('Asr', '02:41', '14:41'),
        ('Maghrib', '05:04', '17:04'),
        ('Isha', '06:18', '18:18'),
        ('Asr', '14:41', '14:41'),
        ('Maghrib', '17:04', '17:04'),
        ('Isha', '18:18', '18:18'),
      ]) {
        final parsed = PrayerTimetableRepository.parseLocalTime(
          raw,
          field: field,
          dateKey: '11-05',
        );
        expect(_clock(parsed), expected, reason: '$field: $raw');
      }
      for (final invalid in ['5:3', '24:00', '12:60', '', '05,11']) {
        expect(
          () => PrayerTimetableRepository.parseLocalTime(
            invalid,
            field: 'Fajr',
            dateKey: '11-05',
          ),
          throwsA(isA<TimetableValidationException>()),
        );
      }
    },
  );

  test('incomplete or duplicated city records are rejected', () {
    final rows = _records();
    rows.removeWhere((row) => row['Date'] == '02-29');
    expect(
      () => PrayerTimetableRepository.parseDataset(
        cityId: 'kalar',
        fileName: 'Kalar.json',
        rawJson: jsonEncode(rows),
        source: TimetableSource.remote,
      ),
      throwsA(isA<TimetableValidationException>()),
    );

    final duplicate = _records()..add(_records().first);
    expect(
      () => PrayerTimetableRepository.parseDataset(
        cityId: 'kalar',
        fileName: 'Kalar.json',
        rawJson: jsonEncode(duplicate),
        source: TimetableSource.remote,
      ),
      throwsA(isA<TimetableValidationException>()),
    );

    final malformed = _records()..first['Fajr'] = '05,11';
    expect(
      () => PrayerTimetableRepository.parseDataset(
        cityId: 'kalar',
        fileName: 'Kalar.json',
        rawJson: jsonEncode(malformed),
        source: TimetableSource.remote,
      ),
      throwsA(isA<TimetableValidationException>()),
    );

    final missingField = _records()..first.remove('Isha');
    expect(
      () => PrayerTimetableRepository.parseDataset(
        cityId: 'kalar',
        fileName: 'Kalar.json',
        rawJson: jsonEncode(missingField),
        source: TimetableSource.remote,
      ),
      throwsA(isA<TimetableValidationException>()),
    );
  });

  test('city switching keeps timetable identity and source distinct', () async {
    final repository = PrayerTimetableRepository(
      store: _MemorySettingsStore(),
      transport: _FixtureTransport(),
    );
    final kalarDataset = await repository.loadCity(kalar);
    final hawlerDataset = await repository.loadCity(hawler);

    expect(kalarDataset.cityId, 'kalar');
    expect(hawlerDataset.cityId, 'erbil');
    expect(repository.datasetFor('kalar'), same(kalarDataset));
    expect(repository.datasetFor('erbil'), same(hawlerDataset));
    expect(
      () => kalarDataset.scheduleFor(
        city: hawler,
        date: DateTime(2024, 11, 5),
        madhab: AsrMadhab.shafi,
        minuteAdjustments: const {},
      ),
      throwsA(isA<TimetableException>()),
    );
  });

  test('valid city cache is used after a failed network request', () async {
    final store = _MemorySettingsStore()
      ..values['prayer_timetable_raw_v1_kalar'] = jsonEncode(_records());
    final repository = PrayerTimetableRepository(
      store: store,
      transport: _FixtureTransport(fail: true),
    );
    final dataset = await repository.loadCity(kalar);
    final schedule = dataset.scheduleFor(
      city: kalar,
      date: DateTime(2024, 11, 5),
      madhab: AsrMadhab.shafi,
      minuteAdjustments: const {},
    );

    expect(dataset.source, TimetableSource.cache);
    expect(schedule.source, PrayerScheduleSource.cachedCityTimetable);
    expect(schedule.times[3].rawValue, '02:41');
  });

  test('invalid cached data is not treated as an available schedule', () async {
    final store = _MemorySettingsStore()
      ..values['prayer_timetable_raw_v1_kalar'] = '{"value":[]}';
    final repository = PrayerTimetableRepository(
      store: store,
      transport: _FixtureTransport(fail: true),
    );
    await expectLater(
      repository.loadCity(kalar),
      throwsA(isA<TimetableException>()),
    );
  });

  test(
    'calculated fallback remains unavailable until explicitly enabled',
    () async {
      final state = BangAppState(
        _MemorySettingsStore(),
        timetableRepository: PrayerTimetableRepository(
          store: _MemorySettingsStore(),
          transport: _FixtureTransport(fail: true),
        ),
      );
      await state.loadScheduleFor(DateTime(2024, 11, 5));

      expect(state.calculatedFallbackEnabled, isFalse);
      expect(state.todaySchedule, isNull);
      expect(state.scheduleError, isNotNull);

      await state.setCalculatedFallbackEnabled(true);
      expect(
        state.todaySchedule?.source,
        PrayerScheduleSource.calculatedFallback,
      );
    },
  );

  test('Baghdad offset, midnight transition and shared next-prayer source', () {
    final dataset = _parse(kalar);
    final today = dataset.scheduleFor(
      city: kalar,
      date: DateTime(2024, 11, 5),
      madhab: AsrMadhab.shafi,
      minuteAdjustments: const {},
    );
    final tomorrow = dataset.scheduleFor(
      city: kalar,
      date: DateTime(2024, 11, 6),
      madhab: AsrMadhab.shafi,
      minuteAdjustments: const {},
    );
    expect(today.times.first.time.timeZoneOffset, const Duration(hours: 3));

    final afterIsha = today.times.last.time.add(const Duration(minutes: 1));
    final next = PrayerSchedule.nextAfter(
      today: today,
      tomorrow: tomorrow,
      now: afterIsha,
    );
    expect(next, same(tomorrow.times.first));

    // Every next-prayer consumer can use this same schedule selector.
    final notificationPrayer = PrayerSchedule.nextAfter(
      today: today,
      tomorrow: tomorrow,
      now: afterIsha,
    );
    expect(notificationPrayer?.time, next?.time);
    expect(notificationPrayer?.id, 'fajr');
    expect(notificationPrayer?.time.day, 6);
  });
}

TimetableDataset _parse(City city) => PrayerTimetableRepository.parseDataset(
  cityId: city.id,
  fileName: city.timetableFile!,
  rawJson: jsonEncode(_records()),
  source: TimetableSource.remote,
);

List<Map<String, Object>> _records() {
  final rows = <Map<String, Object>>[];
  final start = DateTime.utc(2024, 1, 1);
  for (var index = 0; index < 366; index++) {
    final date = start.add(Duration(days: index));
    final key =
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    rows.add({
      'ID': index + 1,
      'Date': key,
      'Fajr': '05:00',
      'Sunrise': '06:00',
      'Dhuhr': '12:00',
      'Asr': '02:00',
      'Maghrib': '05:00',
      'Isha': '06:00',
    });
  }
  final kalar = rows.firstWhere((row) => row['Date'] == '11-05');
  kalar
    ..['Fajr'] = '05:03'
    ..['Sunrise'] = '06:28'
    ..['Dhuhr'] = '11:47'
    ..['Asr'] = '02:41'
    ..['Maghrib'] = '05:04'
    ..['Isha'] = '06:18';
  return rows;
}

String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

class _FixtureTransport implements TimetableTransport {
  _FixtureTransport({this.fail = false});

  final bool fail;

  @override
  Future<String> get(Uri uri) async {
    if (fail) throw http.ClientException('offline');
    return jsonEncode(_records());
  }
}

class _MemorySettingsStore implements SettingsStore {
  final Map<String, Object> values = {};

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    values[key] = value;
  }
}
