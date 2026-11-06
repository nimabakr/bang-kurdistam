import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain/city.dart';
import 'domain/prayer_schedule.dart';
import 'services/baghdad_clock.dart';
import 'services/settings_store.dart';
import 'services/prayer_time_service.dart';
import 'services/prayer_notifications.dart';
import 'services/localization.dart';

enum PrayerLogStatus { completed, missed }

class BangAppState extends ChangeNotifier {
  BangAppState(
    this._preferences, {
    PrayerTimetableRepository? timetableRepository,
  }) : _timetableRepository =
           timetableRepository ??
           PrayerTimetableRepository(
             store: _preferences,
             transport: HttpTimetableTransport(),
           );

  final SettingsStore _preferences;
  final PrayerTimetableRepository _timetableRepository;

  City selectedCity = cities.first;
  ThemeMode themeMode = ThemeMode.system;
  int tasbihCount = 0;
  int tasbihTarget = 33;
  String tasbihDhikr = 'subhanallah';
  bool tasbihHapticsEnabled = true;
  int hijriDateAdjustment = 0;
  AppLanguage appLanguage = AppLanguage.ku;
  Map<String, Map<String, PrayerLogStatus>> prayerLogs = {};
  final Map<String, bool> prayerNotificationsEnabled = {
    'fajr': false,
    'sunrise': false,
    'dhuhr': false,
    'asr': false,
    'maghrib': false,
    'isha': false,
  };
  final Map<String, bool> prayerRemindersEnabled = {
    'fajr': false,
    'sunrise': false,
    'dhuhr': false,
    'asr': false,
    'maghrib': false,
    'isha': false,
  };
  int prayerReminderMinutes = 10;
  bool notificationVibrationEnabled = true;
  bool notificationsSilent = false;
  String? notificationError;
  PrayerNotifications? _prayerNotifications;
  bool calculatedFallbackEnabled = false;
  bool scheduleLoading = false;
  String? scheduleError;
  PrayerSchedule? todaySchedule;
  PrayerSchedule? tomorrowSchedule;
  final _fallbackCalculator = const PrayerTimeService();
  Map<String, int> minuteAdjustments = const {
    'fajr': 0,
    'dhuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };
  Set<String> favoriteCityIds = {};

  static Future<BangAppState> load() async {
    final state = BangAppState(SharedPreferencesSettingsStore());
    final cityId = await state._preferences.getString('city_id');
    final themeName = await state._preferences.getString('theme_mode');
    await state._preferences.remove('madhab');
    await state._preferences.remove('adhan_audio_enabled');
    await state._preferences.remove('adhan_audio_preset');
    final adjustmentsJson = await state._preferences.getString(
      'minute_adjustments',
    );
    final favoriteIds = await state._preferences.getStringList(
      'favorite_city_ids',
    );
    state.calculatedFallbackEnabled =
        await state._preferences.getInt('calculated_fallback_enabled') == 1;

    state.selectedCity = cities.firstWhere(
      (city) => city.id == cityId,
      orElse: () => cities.first,
    );
    state.themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => ThemeMode.system,
    );
    state.tasbihCount = await state._preferences.getInt('tasbih_count') ?? 0;
    state.tasbihDhikr =
        await state._preferences.getString('tasbih_dhikr') ?? 'subhanallah';
    if (!const {
      'subhanallah',
      'alhamdulillah',
      'allahu_akbar',
      'astaghfirullah',
    }.contains(state.tasbihDhikr)) {
      state.tasbihDhikr = 'subhanallah';
    }
    state.tasbihHapticsEnabled =
        await state._preferences.getInt('tasbih_haptics') != 0;
    state.hijriDateAdjustment =
        (await state._preferences.getInt('hijri_adjustment') ?? 0)
            .clamp(-2, 2)
            .toInt();
    final appLanguageCode =
        await state._preferences.getString('app_language') ?? 'ku';
    state.appLanguage = AppLanguage.values.firstWhere(
      (language) => language.code == appLanguageCode,
      orElse: () => AppLanguage.ku,
    );
    final prayerLogsJson = await state._preferences.getString('prayer_logs_v1');
    if (prayerLogsJson != null) {
      final decodedLogs = jsonDecode(prayerLogsJson);
      if (decodedLogs is Map<String, dynamic>) {
        state.prayerLogs = {
          for (final entry in decodedLogs.entries)
            if (entry.value is Map<String, dynamic>)
              entry.key: {
                for (final prayerEntry
                    in (entry.value as Map<String, dynamic>).entries)
                  if (prayerEntry.value == 'completed' ||
                      prayerEntry.value == 'missed')
                    prayerEntry.key: PrayerLogStatus.values.firstWhere(
                      (status) => status.name == prayerEntry.value,
                    ),
              },
        };
      }
    }
    state.prayerNotificationsEnabled.addAll(
      _decodeBoolMap(
        await state._preferences.getString('prayer_notifications_v1'),
        state.prayerNotificationsEnabled,
      ),
    );
    state.prayerRemindersEnabled.addAll(
      _decodeBoolMap(
        await state._preferences.getString('prayer_reminders_v1'),
        state.prayerRemindersEnabled,
      ),
    );
    state.prayerReminderMinutes =
        (await state._preferences.getInt('prayer_reminder_minutes') ?? 10)
            .clamp(5, 30)
            .toInt();
    if (![5, 10, 15, 30].contains(state.prayerReminderMinutes)) {
      state.prayerReminderMinutes = 10;
    }
    state.notificationVibrationEnabled =
        await state._preferences.getInt('notification_vibration') != 0;
    state.notificationsSilent =
        await state._preferences.getInt('notifications_silent') == 1;
    final savedTarget = await state._preferences.getInt('tasbih_target');
    state.tasbihTarget = const [33, 99, 100, 1000].contains(savedTarget)
        ? savedTarget!
        : 33;
    if (favoriteIds != null) state.favoriteCityIds = favoriteIds.toSet();

    if (adjustmentsJson != null) {
      final decoded = jsonDecode(adjustmentsJson);
      if (decoded is Map<String, dynamic>) {
        state.minuteAdjustments = {
          for (final prayer in const [
            'fajr',
            'dhuhr',
            'asr',
            'maghrib',
            'isha',
          ])
            prayer: decoded[prayer] is int ? decoded[prayer] as int : 0,
        };
      }
    }

    return state;
  }

  static Map<String, bool> _decodeBoolMap(
    String? encoded,
    Map<String, bool> defaults,
  ) {
    if (encoded == null) return {};
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return {};
    return {
      for (final entry in defaults.entries)
        entry.key: decoded[entry.key] is bool
            ? decoded[entry.key] as bool
            : entry.value,
    };
  }

  bool get notificationsSupported => _prayerNotifications?.isSupported ?? false;

  void attachPrayerNotifications(PrayerNotifications service) {
    _prayerNotifications = service;
  }

  Future<void> selectCity(City city) async {
    selectedCity = city;
    todaySchedule = null;
    tomorrowSchedule = null;
    scheduleError = null;
    notifyListeners();
    await _preferences.setString('city_id', city.id);
    await loadScheduleFor(baghdadNow());
  }

  PrayerSchedule? scheduleFor(DateTime date) {
    final dataset = _timetableRepository.datasetFor(selectedCity.id);
    if (dataset != null) {
      try {
        return dataset.scheduleFor(
          city: selectedCity,
          date: date,
          minuteAdjustments: minuteAdjustments,
        );
      } on TimetableException {
        if (!calculatedFallbackEnabled) return null;
      }
    }
    if (!calculatedFallbackEnabled) return null;
    if (selectedCity.latitude == null || selectedCity.longitude == null) {
      return null;
    }
    return _fallbackCalculator.calculateFallback(
      city: selectedCity,
      date: date,
      minuteAdjustments: minuteAdjustments,
    );
  }

  Future<void> loadScheduleFor(DateTime date) async {
    final requestedCity = selectedCity;
    scheduleLoading = true;
    scheduleError = null;
    notifyListeners();
    try {
      await _timetableRepository.loadCity(requestedCity);
      if (requestedCity.id != selectedCity.id) return;
      final today = baghdadDate(date);
      todaySchedule = scheduleFor(today);
      tomorrowSchedule = scheduleFor(today.add(const Duration(days: 1)));
      if (todaySchedule == null || tomorrowSchedule == null) {
        throw const TimetableException('A required day is missing.');
      }
    } on TimetableException catch (error) {
      if (requestedCity.id != selectedCity.id) return;
      if (calculatedFallbackEnabled &&
          requestedCity.latitude != null &&
          requestedCity.longitude != null) {
        final today = baghdadDate(date);
        todaySchedule = _fallbackCalculator.calculateFallback(
          city: requestedCity,
          date: today,
          minuteAdjustments: minuteAdjustments,
        );
        tomorrowSchedule = _fallbackCalculator.calculateFallback(
          city: requestedCity,
          date: today.add(const Duration(days: 1)),
          minuteAdjustments: minuteAdjustments,
        );
      } else {
        todaySchedule = null;
        tomorrowSchedule = null;
        scheduleError = error.message;
      }
    } finally {
      if (requestedCity.id == selectedCity.id) {
        scheduleLoading = false;
        notifyListeners();
      }
    }
    await _reschedulePrayerNotifications();
  }

  Future<void> _reschedulePrayerNotifications() async {
    final service = _prayerNotifications;
    if (service == null || !service.isSupported) return;
    final now = baghdadNow();
    final today = baghdadDate(now);
    final schedules = <PrayerSchedule>[];
    for (var offset = 0; offset < 5; offset++) {
      final schedule = scheduleFor(today.add(Duration(days: offset)));
      if (schedule != null) schedules.add(schedule);
    }
    try {
      await service.reschedule(
        schedules: schedules,
        enabled: prayerNotificationsEnabled,
        remindersEnabled: prayerRemindersEnabled,
        reminderMinutes: prayerReminderMinutes,
        vibration: notificationVibrationEnabled,
        silent: notificationsSilent,
        language: appLanguage,
        now: now,
      );
      notificationError = null;
    } on PlatformException catch (error) {
      notificationError = 'نۆتیفیکەیشن نەتوانرا نوێ بکرێتەوە: ${error.message}';
    } on MissingPluginException catch (error) {
      notificationError = 'خزمەتی نۆتیفیکەیشن بەردەست نییە: ${error.message}';
    } on UnsupportedError catch (error) {
      notificationError = error.message;
    } on StateError catch (error) {
      notificationError = error.message;
    }
    notifyListeners();
  }

  Future<void> refreshPrayerNotifications() => loadScheduleFor(baghdadNow());

  Future<void> setPrayerNotificationsEnabled(
    String prayerId,
    bool enabled,
  ) async {
    if (!prayerNotificationsEnabled.containsKey(prayerId)) {
      throw ArgumentError.value(prayerId, 'prayerId', 'Unknown prayer');
    }
    if (enabled) {
      final service = _prayerNotifications;
      if (service == null || !service.isSupported) {
        notificationError = 'نۆتیفیکەیشن لەم پلاتفۆرمەدا پشتگیری ناکرێت.';
        notifyListeners();
        return;
      }
      late final bool granted;
      try {
        granted = await service.requestPermission();
      } on PlatformException catch (error) {
        notificationError = 'مۆڵەتی نۆتیفیکەیشن وەرنەگیرا: ${error.message}';
        notifyListeners();
        return;
      } on MissingPluginException catch (error) {
        notificationError = 'خزمەتی نۆتیفیکەیشن بەردەست نییە: ${error.message}';
        notifyListeners();
        return;
      } on StateError catch (error) {
        notificationError = error.message;
        notifyListeners();
        return;
      }
      if (!granted) {
        notificationError =
            'مۆڵەتی نۆتیفیکەیشن نەدراوە؛ لە ڕێکخستنەکانی ئامێرەکەت چالاکی بکە.';
        notifyListeners();
        return;
      }
    }
    prayerNotificationsEnabled[prayerId] = enabled;
    await _preferences.setString(
      'prayer_notifications_v1',
      jsonEncode(prayerNotificationsEnabled),
    );
    notifyListeners();
    await _reschedulePrayerNotifications();
  }

  Future<void> setPrayerReminderEnabled(String prayerId, bool enabled) async {
    if (!prayerRemindersEnabled.containsKey(prayerId)) {
      throw ArgumentError.value(prayerId, 'prayerId', 'Unknown prayer');
    }
    prayerRemindersEnabled[prayerId] = enabled;
    await _preferences.setString(
      'prayer_reminders_v1',
      jsonEncode(prayerRemindersEnabled),
    );
    notifyListeners();
    await _reschedulePrayerNotifications();
  }

  Future<void> setPrayerReminderMinutes(int minutes) async {
    if (![5, 10, 15, 30].contains(minutes)) {
      throw ArgumentError.value(minutes, 'minutes', 'Unsupported reminder');
    }
    prayerReminderMinutes = minutes;
    await _preferences.setInt('prayer_reminder_minutes', minutes);
    notifyListeners();
    await _reschedulePrayerNotifications();
  }

  Future<void> setNotificationVibration(bool enabled) async {
    notificationVibrationEnabled = enabled;
    await _preferences.setInt('notification_vibration', enabled ? 1 : 0);
    notifyListeners();
    await _reschedulePrayerNotifications();
  }

  Future<void> setNotificationsSilent(bool silent) async {
    notificationsSilent = silent;
    await _preferences.setInt('notifications_silent', silent ? 1 : 0);
    notifyListeners();
    await _reschedulePrayerNotifications();
  }

  Future<void> sendTestNotification() async {
    final service = _prayerNotifications;
    if (service == null || !service.isSupported) {
      throw UnsupportedError('نۆتیفیکەیشن لەم پلاتفۆرمەدا بەردەست نییە.');
    }
    await service.showTest(
      language: appLanguage,
      vibration: notificationVibrationEnabled,
      silent: notificationsSilent,
    );
  }

  PrayerTime? nextPrayerAt(DateTime now) {
    return PrayerSchedule.nextAfter(
      today: todaySchedule,
      tomorrow: tomorrowSchedule,
      now: now,
    );
  }

  Future<void> setCalculatedFallbackEnabled(bool enabled) async {
    calculatedFallbackEnabled = enabled;
    await _preferences.setInt('calculated_fallback_enabled', enabled ? 1 : 0);
    await loadScheduleFor(baghdadNow());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _preferences.setString('theme_mode', mode.name);
  }

  void _refreshSchedules() {
    final now = baghdadNow();
    todaySchedule = scheduleFor(now);
    tomorrowSchedule = scheduleFor(now.add(const Duration(days: 1)));
  }

  Future<void> setTasbihCount(int value) async {
    tasbihCount = value < 0 ? 0 : value;
    notifyListeners();
    await _preferences.setInt('tasbih_count', tasbihCount);
  }

  Future<void> setTasbihTarget(int value) async {
    if (value < 1 || value > 100000) {
      throw ArgumentError.value(value, 'value', 'Unsupported Tasbih target');
    }
    tasbihTarget = value;
    notifyListeners();
    await _preferences.setInt('tasbih_target', value);
  }

  Future<void> setTasbihDhikr(String value) async {
    if (!const {
      'subhanallah',
      'alhamdulillah',
      'allahu_akbar',
      'astaghfirullah',
    }.contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported Dhikr');
    }
    tasbihDhikr = value;
    notifyListeners();
    await _preferences.setString('tasbih_dhikr', value);
  }

  Future<void> setTasbihHapticsEnabled(bool enabled) async {
    tasbihHapticsEnabled = enabled;
    notifyListeners();
    await _preferences.setInt('tasbih_haptics', enabled ? 1 : 0);
  }

  Future<void> setHijriDateAdjustment(int value) async {
    hijriDateAdjustment = value.clamp(-2, 2).toInt();
    notifyListeners();
    await _preferences.setInt('hijri_adjustment', hijriDateAdjustment);
  }

  Future<void> setAppLanguage(AppLanguage language) async {
    appLanguage = language;
    notifyListeners();
    await _preferences.setString('app_language', language.code);
  }

  PrayerLogStatus? prayerStatus(DateTime date, String prayerId) =>
      prayerLogs[_dateKey(date)]?[prayerId];

  Future<void> setPrayerStatus(
    DateTime date,
    String prayerId,
    PrayerLogStatus? status,
  ) async {
    final key = _dateKey(date);
    final dayLogs = {...?prayerLogs[key]};
    if (status == null) {
      dayLogs.remove(prayerId);
    } else {
      dayLogs[prayerId] = status;
    }
    prayerLogs = {...prayerLogs};
    if (dayLogs.isEmpty) {
      prayerLogs.remove(key);
    } else {
      prayerLogs[key] = dayLogs;
    }
    notifyListeners();
    await _preferences.setString(
      'prayer_logs_v1',
      jsonEncode({
        for (final day in prayerLogs.entries)
          day.key: {
            for (final prayer in day.value.entries)
              prayer.key: prayer.value.name,
          },
      }),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> setMinuteAdjustment(String prayer, int value) async {
    if (!minuteAdjustments.containsKey(prayer)) {
      throw ArgumentError.value(prayer, 'prayer', 'Unknown prayer');
    }
    minuteAdjustments = {
      ...minuteAdjustments,
      prayer: value.clamp(-60, 60).toInt(),
    };
    _refreshSchedules();
    notifyListeners();
    await _preferences.setString(
      'minute_adjustments',
      jsonEncode(minuteAdjustments),
    );
    await _reschedulePrayerNotifications();
  }

  Future<void> toggleFavorite(City city) async {
    if (!favoriteCityIds.add(city.id)) favoriteCityIds.remove(city.id);
    notifyListeners();
    await _preferences.setStringList(
      'favorite_city_ids',
      favoriteCityIds.toList(),
    );
  }

  Future<void> clearPersonalData() async {
    tasbihCount = 0;
    minuteAdjustments = const {
      'fajr': 0,
      'dhuhr': 0,
      'asr': 0,
      'maghrib': 0,
      'isha': 0,
    };
    favoriteCityIds = {};
    notifyListeners();
    await _preferences.remove('tasbih_count');
    await _preferences.remove('minute_adjustments');
    await _preferences.remove('favorite_city_ids');
    prayerLogs = {};
    tasbihDhikr = 'subhanallah';
    tasbihHapticsEnabled = true;
    hijriDateAdjustment = 0;
    appLanguage = AppLanguage.ku;
    await _preferences.remove('prayer_logs_v1');
    await _preferences.remove('tasbih_dhikr');
    await _preferences.remove('tasbih_haptics');
    await _preferences.remove('hijri_adjustment');
    await _preferences.remove('app_language');
    prayerNotificationsEnabled.updateAll((_, _) => false);
    prayerRemindersEnabled.updateAll((_, _) => false);
    prayerReminderMinutes = 10;
    notificationVibrationEnabled = true;
    notificationsSilent = false;
    await _preferences.remove('prayer_notifications_v1');
    await _preferences.remove('prayer_reminders_v1');
    await _preferences.remove('prayer_reminder_minutes');
    await _preferences.remove('notification_vibration');
    await _preferences.remove('notifications_silent');
    await _reschedulePrayerNotifications();
  }
}
