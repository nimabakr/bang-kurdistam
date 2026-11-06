import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/prayer_schedule.dart';
import 'baghdad_clock.dart';

class PrayerAlert {
  const PrayerAlert({
    required this.id,
    required this.prayerId,
    required this.scheduledAt,
    required this.isReminder,
  });

  final int id;
  final String prayerId;
  final tz.TZDateTime scheduledAt;
  final bool isReminder;
}

class PrayerNotifications {
  PrayerNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const idStart = 4000000;
  static const idEnd = 8500000;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isSupported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return result ?? false;
  }

  Future<void> showTest({
    required String title,
    required String body,
    required bool vibration,
    required bool silent,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Native notifications are unavailable here.');
    }
    _ensureInitialized();
    await _plugin.show(
      id: idEnd,
      title: title,
      body: body,
      notificationDetails: _details(vibration: vibration, silent: silent),
    );
  }

  Future<void> reschedule({
    required List<PrayerSchedule> schedules,
    required Map<String, bool> enabled,
    required Map<String, bool> remindersEnabled,
    required int reminderMinutes,
    required bool vibration,
    required bool silent,
    required DateTime now,
  }) async {
    if (!isSupported) return;
    _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (notification.id >= idStart && notification.id < idEnd) {
        await _plugin.cancel(id: notification.id);
      }
    }

    final alerts = buildPlan(
      schedules: schedules,
      enabled: enabled,
      remindersEnabled: remindersEnabled,
      reminderMinutes: reminderMinutes,
      now: now,
    );
    for (final alert in alerts) {
      await _plugin.zonedSchedule(
        id: alert.id,
        title: _title(alert.prayerId),
        body: alert.isReminder
            ? 'ماوەی $reminderMinutes خولەک بۆ بانگ'
            : 'کاتی بانگی نوێژە',
        scheduledDate: alert.scheduledAt,
        notificationDetails: _details(vibration: vibration, silent: silent),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${schedules.first.cityId}:${alert.prayerId}',
      );
    }
  }

  static List<PrayerAlert> buildPlan({
    required List<PrayerSchedule> schedules,
    required Map<String, bool> enabled,
    required Map<String, bool> remindersEnabled,
    required int reminderMinutes,
    required DateTime now,
  }) {
    if (schedules.isEmpty) return const [];
    final cityId = schedules.first.cityId;
    final nowInBaghdad = tz.TZDateTime.from(now, baghdadLocation);
    final alerts = <PrayerAlert>[];
    final orderedSchedules = schedules.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final schedule in orderedSchedules) {
      if (schedule.cityId != cityId ||
          schedule.source == PrayerScheduleSource.calculatedFallback) {
        continue;
      }
      for (var index = 0; index < schedule.times.length; index++) {
        final prayer = schedule.times[index];
        if (enabled[prayer.id] != true) continue;
        final prayerTime = tz.TZDateTime.from(prayer.time, baghdadLocation);
        final localDate = DateTime.utc(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
        );
        final dateOrdinal =
            schedule.date.year.remainder(1000) * 366 +
            localDate.difference(DateTime.utc(schedule.date.year)).inDays +
            1;
        final baseId = idStart + dateOrdinal * 12 + index * 2;
        if (prayerTime.isAfter(nowInBaghdad)) {
          alerts.add(
            PrayerAlert(
              id: baseId,
              prayerId: prayer.id,
              scheduledAt: prayerTime,
              isReminder: false,
            ),
          );
        }
        final reminderTime = prayerTime.subtract(
          Duration(minutes: reminderMinutes),
        );
        if (remindersEnabled[prayer.id] == true &&
            reminderTime.isAfter(nowInBaghdad)) {
          alerts.add(
            PrayerAlert(
              id: baseId + 1,
              prayerId: prayer.id,
              scheduledAt: reminderTime,
              isReminder: true,
            ),
          );
        }
      }
    }
    return alerts;
  }

  NotificationDetails _details({
    required bool vibration,
    required bool silent,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_times_${silent ? 'silent' : 'sound'}_'
          '${vibration ? 'vibration' : 'no_vibration'}',
      'Prayer times',
      channelDescription: 'Prayer time reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: vibration,
      playSound: !silent,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: !silent,
    ),
  );

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Prayer notifications have not been initialized.');
    }
  }

  static String _title(String prayerId) => switch (prayerId) {
    'fajr' => 'بانگی بەیانی',
    'sunrise' => 'هەڵاتنی خۆر',
    'dhuhr' => 'بانگی نیوەڕۆ',
    'asr' => 'بانگی عەسر',
    'maghrib' => 'بانگی ئێوارە',
    'isha' => 'بانگی خەوتنان',
    _ => 'کاتی نوێژ',
  };
}
