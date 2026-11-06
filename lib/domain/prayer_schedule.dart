class PrayerTime {
  const PrayerTime({
    required this.id,
    required this.name,
    required this.time,
    required this.rawValue,
    this.isSunrise = false,
  });

  final String id;
  final String name;
  final DateTime time;
  final String rawValue;
  final bool isSunrise;
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.cityId,
    required this.date,
    required this.times,
    required this.source,
    required this.sourceReference,
  });

  final String cityId;
  final DateTime date;
  final List<PrayerTime> times;
  final PrayerScheduleSource source;
  final String sourceReference;

  List<PrayerTime> get obligatory =>
      times.where((prayer) => !prayer.isSunrise).toList(growable: false);

  static PrayerTime? nextAfter({
    required PrayerSchedule? today,
    required PrayerSchedule? tomorrow,
    required DateTime now,
  }) {
    for (final prayer in today?.obligatory ?? const <PrayerTime>[]) {
      if (prayer.time.isAfter(now)) return prayer;
    }
    return tomorrow?.obligatory.firstOrNull;
  }
}

enum PrayerScheduleSource {
  cityTimetable,
  cachedCityTimetable,
  calculatedFallback,
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
