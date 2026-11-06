import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import '../domain/city.dart';
import '../domain/prayer_schedule.dart';
import 'settings_store.dart';

enum AsrMadhab { shafi, hanafi }

enum TimetableSource { remote, cache }

class TimetableException implements Exception {
  const TimetableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TimetableHttpException extends TimetableException {
  const TimetableHttpException(super.message);
}

class TimetableValidationException extends TimetableException {
  const TimetableValidationException(super.message);
}

class TimetableRecord {
  const TimetableRecord({
    required this.id,
    required this.dateKey,
    required this.rawTimes,
    required this.times,
  });

  final String id;
  final String dateKey;
  final Map<String, String> rawTimes;
  final Map<String, DateTime> times;
}

class TimetableDataset {
  const TimetableDataset({
    required this.cityId,
    required this.fileName,
    required this.records,
    required this.source,
    required this.validatedAt,
  });

  final String cityId;
  final String fileName;
  final Map<String, TimetableRecord> records;
  final TimetableSource source;
  final DateTime validatedAt;

  PrayerSchedule scheduleFor({
    required City city,
    required DateTime date,
    required AsrMadhab madhab,
    required Map<String, int> minuteAdjustments,
  }) {
    if (city.id != cityId) {
      throw TimetableException('Timetable city does not match the selection.');
    }

    final dateKey =
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final record = records[dateKey];
    if (record == null) {
      throw TimetableException(
        'No timetable entry for ${city.englishName} on $dateKey.',
      );
    }

    final location = tz.getLocation(city.timezone);
    final definitions = const [
      ('fajr', 'بەیانی', 'Fajr', true, false),
      ('sunrise', 'هەڵاتنی خۆر', 'Sunrise', true, true),
      ('dhuhr', 'نیوەڕۆ', 'Dhuhr', true, false),
      ('asr', 'عەسر', 'Asr', true, false),
      ('maghrib', 'ئێوارە', 'Maghrib', true, false),
      ('isha', 'خەوتنان', 'Isha', true, false),
    ];

    final times = definitions
        .map((definition) {
          final (id, name, field, _, isSunrise) = definition;
          final correction = isSunrise ? 0 : (minuteAdjustments[id] ?? 0);
          final wallTime = record.times[field]!.add(
            Duration(minutes: correction),
          );
          final localTime = tz.TZDateTime(
            location,
            date.year,
            date.month,
            date.day,
            wallTime.hour,
            wallTime.minute,
          );
          return PrayerTime(
            id: id,
            name: name,
            time: localTime,
            rawValue: record.rawTimes[field]!,
            isSunrise: isSunrise,
          );
        })
        .toList(growable: false);

    final source = this.source == TimetableSource.remote
        ? PrayerScheduleSource.cityTimetable
        : PrayerScheduleSource.cachedCityTimetable;
    return PrayerSchedule(
      cityId: city.id,
      date: tz.TZDateTime(location, date.year, date.month, date.day),
      times: times,
      source: source,
      sourceReference: fileName,
    );
  }
}

abstract interface class TimetableTransport {
  Future<String> get(Uri uri);
}

class HttpTimetableTransport implements TimetableTransport {
  HttpTimetableTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> get(Uri uri) async {
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TimetableHttpException(
        'Timetable request failed with HTTP ${response.statusCode}.',
      );
    }
    return response.body;
  }

  void close() => _client.close();
}

class PrayerTimetableRepository {
  PrayerTimetableRepository({required this.store, required this.transport});

  static const baseUrl =
      'https://raw.githubusercontent.com/Bang-Kurdistan/'
      'kurdistan-prayer-times/main/data/';
  static const dataAttribution =
      'Bang-Kurdistan/kurdistan-prayer-times; not government-certified.';
  static const _cachePrefix = 'prayer_timetable_raw_v1_';

  final SettingsStore store;
  final TimetableTransport transport;
  final Map<String, TimetableDataset> _datasets = {};

  TimetableDataset? datasetFor(String cityId) => _datasets[cityId];

  Future<TimetableDataset> loadCity(City city) async {
    final fileName = city.timetableFile;
    if (fileName == null) {
      throw TimetableException(
        'No city timetable is available for ${city.englishName}.',
      );
    }

    Object? networkFailure;
    try {
      final uri = Uri.parse('$baseUrl$fileName');
      final body = await transport.get(uri);
      final dataset = parseDataset(
        cityId: city.id,
        fileName: fileName,
        rawJson: body,
        source: TimetableSource.remote,
      );
      await store.setString('$_cachePrefix${city.id}', body);
      _datasets[city.id] = dataset;
      return dataset;
    } on TimetableException catch (error) {
      networkFailure = error;
    } on TimeoutException catch (error) {
      networkFailure = error;
    } on http.ClientException catch (error) {
      networkFailure = error;
    } on SocketException catch (error) {
      networkFailure = error;
    } on FormatException catch (error) {
      networkFailure = error;
    }

    final cached = await _readValidCache(city, fileName);
    if (cached != null) {
      _datasets[city.id] = cached;
      return cached;
    }
    throw TimetableException(
      'No valid timetable or cached schedule for ${city.englishName}. '
      '$networkFailure',
    );
  }

  Future<TimetableDataset?> _readValidCache(City city, String fileName) async {
    final cachedJson = await store.getString('$_cachePrefix${city.id}');
    if (cachedJson == null) return null;
    try {
      return parseDataset(
        cityId: city.id,
        fileName: fileName,
        rawJson: cachedJson,
        source: TimetableSource.cache,
      );
    } on TimetableException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static TimetableDataset parseDataset({
    required String cityId,
    required String fileName,
    required String rawJson,
    required TimetableSource source,
    DateTime? validatedAt,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw TimetableValidationException('Invalid JSON: ${error.message}');
    }

    final Object? rawRecords = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['value'] ?? decoded['data']
        : null;
    if (rawRecords is! List) {
      throw const TimetableValidationException(
        'Expected a JSON array of timetable entries.',
      );
    }

    final records = <String, TimetableRecord>{};
    for (final rawRecord in rawRecords) {
      if (rawRecord is! Map<String, dynamic>) {
        throw const TimetableValidationException(
          'A timetable row is not a JSON object.',
        );
      }
      final dateKey = rawRecord['Date'];
      if (dateKey is! String) {
        throw const TimetableValidationException(
          'A timetable row has no string Date field.',
        );
      }
      _validateDateKey(dateKey, 2024);
      if (records.containsKey(dateKey)) {
        throw TimetableValidationException(
          'Duplicate timetable date $dateKey in $fileName.',
        );
      }

      final rawTimes = <String, String>{};
      final normalizedTimes = <String, DateTime>{};
      for (final field in const [
        'Fajr',
        'Sunrise',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]) {
        final value = rawRecord[field];
        if (value is! String) {
          throw TimetableValidationException(
            'Missing or invalid $field value for $dateKey in $fileName.',
          );
        }
        rawTimes[field] = value;
        normalizedTimes[field] = parseLocalTime(
          value,
          field: field,
          dateKey: dateKey,
        );
      }
      _validateOrdering(dateKey, normalizedTimes, fileName);
      records[dateKey] = TimetableRecord(
        id: '${rawRecord['ID'] ?? dateKey}',
        dateKey: dateKey,
        rawTimes: Map.unmodifiable(rawTimes),
        times: Map.unmodifiable(normalizedTimes),
      );
    }

    final expectedDates = _expectedDateKeys(2024);
    final missing = expectedDates.where((key) => !records.containsKey(key));
    if (records.length != expectedDates.length || missing.isNotEmpty) {
      throw TimetableValidationException(
        'Incomplete timetable $fileName: ${records.length} unique dates; '
        'missing ${missing.take(5).join(', ')}.',
      );
    }

    return TimetableDataset(
      cityId: cityId,
      fileName: fileName,
      records: Map.unmodifiable(records),
      source: source,
      validatedAt: validatedAt ?? DateTime.now().toUtc(),
    );
  }

  static DateTime parseLocalTime(
    String value, {
    required String field,
    required String dateKey,
  }) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      throw TimetableValidationException(
        'Invalid $field time "$value" on $dateKey.',
      );
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw TimetableValidationException(
        'Out-of-range $field time "$value" on $dateKey.',
      );
    }

    final afternoonField = const {'Asr', 'Maghrib', 'Isha'}.contains(field);
    final normalizedHour = afternoonField && hour < 12 ? hour + 12 : hour;
    return DateTime.utc(2024, 1, 1, normalizedHour, minute);
  }

  static DateTime parseMonthDay(String dateKey, {required int year}) {
    _validateDateKey(dateKey, year);
    final month = int.parse(dateKey.substring(0, 2));
    final day = int.parse(dateKey.substring(3, 5));
    return DateTime.utc(year, month, day);
  }

  static void _validateDateKey(String dateKey, int year) {
    if (!RegExp(r'^(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$').hasMatch(dateKey)) {
      throw TimetableValidationException('Invalid MM-DD date "$dateKey".');
    }
    final month = int.parse(dateKey.substring(0, 2));
    final day = int.parse(dateKey.substring(3, 5));
    final candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      throw TimetableValidationException('Invalid MM-DD date "$dateKey".');
    }
  }

  static Set<String> _expectedDateKeys(int year) {
    final dayCount =
        DateTime.utc(year, 12, 31).difference(DateTime.utc(year, 1, 1)).inDays +
        1;
    return {
      for (var index = 0; index < dayCount; index++)
        () {
          final date = DateTime.utc(year, 1, 1).add(Duration(days: index));
          return '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';
        }(),
    };
  }

  static void _validateOrdering(
    String dateKey,
    Map<String, DateTime> times,
    String fileName,
  ) {
    const fields = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (var index = 1; index < fields.length; index++) {
      if (!times[fields[index]]!.isAfter(times[fields[index - 1]]!)) {
        throw TimetableValidationException(
          'Prayer time order is invalid on $dateKey in $fileName.',
        );
      }
    }
  }
}

class PrayerTimeService {
  const PrayerTimeService();

  PrayerSchedule calculateFallback({
    required City city,
    required DateTime date,
    required AsrMadhab madhab,
    required Map<String, int> minuteAdjustments,
  }) {
    final latitude = city.latitude;
    final longitude = city.longitude;
    if (latitude == null || longitude == null) {
      throw TimetableException(
        'Coordinates are unavailable for ${city.englishName}.',
      );
    }
    final parameters = adhan.CalculationMethodParameters.muslimWorldLeague();
    parameters.madhab = madhab == AsrMadhab.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;
    parameters.adjustments = {
      adhan.Prayer.fajr: minuteAdjustments['fajr'] ?? 0,
      adhan.Prayer.dhuhr: minuteAdjustments['dhuhr'] ?? 0,
      adhan.Prayer.asr: minuteAdjustments['asr'] ?? 0,
      adhan.Prayer.maghrib: minuteAdjustments['maghrib'] ?? 0,
      adhan.Prayer.isha: minuteAdjustments['isha'] ?? 0,
    };

    final result = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(latitude, longitude),
      date: DateTime.utc(date.year, date.month, date.day),
      calculationParameters: parameters,
    );
    final location = tz.getLocation(city.timezone);
    final values = [
      ('fajr', 'بەیانی', 'Fajr', result.fajr, false),
      ('sunrise', 'هەڵاتنی خۆر', 'Sunrise', result.sunrise, true),
      ('dhuhr', 'نیوەڕۆ', 'Dhuhr', result.dhuhr, false),
      ('asr', 'عەسر', 'Asr', result.asr, false),
      ('maghrib', 'ئێوارە', 'Maghrib', result.maghrib, false),
      ('isha', 'خەوتنان', 'Isha', result.isha, false),
    ];
    final times = values
        .map((value) {
          final (id, name, _, utcTime, sunrise) = value;
          final adjustment = sunrise ? 0 : (minuteAdjustments[id] ?? 0);
          final localBase = tz.TZDateTime.from(utcTime, location);
          return PrayerTime(
            id: id,
            name: name,
            time: localBase.add(Duration(minutes: adjustment)),
            rawValue:
                '${utcTime.hour.toString().padLeft(2, '0')}:'
                '${utcTime.minute.toString().padLeft(2, '0')}',
            isSunrise: sunrise,
          );
        })
        .toList(growable: false);
    return PrayerSchedule(
      cityId: city.id,
      date: tz.TZDateTime(location, date.year, date.month, date.day),
      times: times,
      source: PrayerScheduleSource.calculatedFallback,
      sourceReference: 'Muslim World League · $madhab',
    );
  }
}
