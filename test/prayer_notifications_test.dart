import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_bang/domain/prayer_schedule.dart';
import 'package:kurdistan_bang/services/baghdad_clock.dart';
import 'package:kurdistan_bang/services/prayer_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(initializeBangTimeZones);

  test('plans use the shared local timetable and omit calculated fallback', () {
    final schedules = [
      _schedule('kalar', DateTime(2024, 11, 5)),
      _schedule('kalar', DateTime(2024, 11, 6)),
      _schedule(
        'kalar',
        DateTime(2024, 11, 7),
        source: PrayerScheduleSource.cachedCityTimetable,
      ),
      _schedule(
        'kalar',
        DateTime(2024, 11, 8),
        source: PrayerScheduleSource.calculatedFallback,
      ),
      _schedule('erbil', DateTime(2024, 11, 5)),
    ];
    final enabled = {for (final prayer in _prayers) prayer.$1: true};
    final reminders = {for (final prayer in _prayers) prayer.$1: false}
      ..['fajr'] = true;
    final now = tz.TZDateTime(baghdadLocation, 2024, 11, 5, 4);

    final alerts = PrayerNotifications.buildPlan(
      schedules: schedules,
      enabled: enabled,
      remindersEnabled: reminders,
      reminderMinutes: 10,
      now: now,
    );

    expect(alerts, hasLength(21));
    expect(alerts.map((alert) => alert.id).toSet(), hasLength(alerts.length));
    expect(
      alerts.every((alert) => alert.scheduledAt.location == baghdadLocation),
      isTrue,
    );
    expect(
      alerts.where((alert) => alert.isReminder).map((alert) => alert.prayerId),
      everyElement('fajr'),
    );
    expect(
      alerts.where((alert) => alert.isReminder).first.scheduledAt,
      tz.TZDateTime(baghdadLocation, 2024, 11, 5, 4, 53),
    );
    expect(
      alerts.where((alert) => !alert.isReminder).map((alert) => alert.prayerId),
      everyElement(isNotEmpty),
    );
  });

  test('city switching only schedules the newly selected city', () {
    final alerts = PrayerNotifications.buildPlan(
      schedules: [_schedule('erbil', DateTime(2024, 11, 5))],
      enabled: {'fajr': true},
      remindersEnabled: const {},
      reminderMinutes: 10,
      now: tz.TZDateTime(baghdadLocation, 2024, 11, 5, 4),
    );

    expect(alerts, hasLength(1));
    expect(alerts.single.prayerId, 'fajr');
  });

  test('notification identifiers remain unique across a year boundary', () {
    final alerts = PrayerNotifications.buildPlan(
      schedules: [
        _schedule('kalar', DateTime(2024, 12, 31)),
        _schedule('kalar', DateTime(2025, 1, 1)),
      ],
      enabled: {for (final prayer in _prayers) prayer.$1: true},
      remindersEnabled: const {},
      reminderMinutes: 10,
      now: tz.TZDateTime(baghdadLocation, 2024, 12, 31),
    );

    expect(alerts, hasLength(12));
    expect(alerts.map((alert) => alert.id).toSet(), hasLength(12));
  });
}

const _prayers = [
  ('fajr', 'Fajr', 5, 3),
  ('sunrise', 'Sunrise', 6, 28),
  ('dhuhr', 'Dhuhr', 11, 47),
  ('asr', 'Asr', 14, 41),
  ('maghrib', 'Maghrib', 17, 4),
  ('isha', 'Isha', 18, 18),
];

PrayerSchedule _schedule(
  String cityId,
  DateTime date, {
  PrayerScheduleSource source = PrayerScheduleSource.cityTimetable,
}) {
  final day = baghdadDate(date);
  return PrayerSchedule(
    cityId: cityId,
    date: day,
    source: source,
    sourceReference: 'test',
    times: [
      for (final prayer in _prayers)
        PrayerTime(
          id: prayer.$1,
          name: prayer.$2,
          rawValue: 'test',
          isSunrise: prayer.$1 == 'sunrise',
          time: tz.TZDateTime(
            baghdadLocation,
            day.year,
            day.month,
            day.day,
            prayer.$3,
            prayer.$4,
          ),
        ),
    ],
  );
}
