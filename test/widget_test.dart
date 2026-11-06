import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_bang/app_state.dart';
import 'package:kurdistan_bang/main.dart';
import 'package:kurdistan_bang/services/baghdad_clock.dart';
import 'package:kurdistan_bang/services/hijri_calendar.dart';
import 'package:kurdistan_bang/services/prayer_time_service.dart';
import 'package:kurdistan_bang/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeBangTimeZones();

  test(
    'selected settings persist and invalid Tasbih targets are rejected',
    () async {
      final store = _MemorySettingsStore();
      final state = BangAppState(store);

      await state.setThemeMode(ThemeMode.dark);
      await state.setTasbihTarget(99);

      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getInt('tasbih_target'), 99);
      await state.setTasbihTarget(125);
      expect(await store.getInt('tasbih_target'), 125);
      await expectLater(state.setTasbihTarget(100001), throwsArgumentError);
    },
  );

  test(
    'prayer tracker records, edits and clears daily prayer status',
    () async {
      final store = _MemorySettingsStore();
      final state = BangAppState(store);
      final date = DateTime(2026, 11, 5);

      await state.setPrayerStatus(date, 'fajr', PrayerLogStatus.completed);
      await state.setPrayerStatus(date, 'isha', PrayerLogStatus.missed);
      expect(state.prayerStatus(date, 'fajr'), PrayerLogStatus.completed);
      expect(state.prayerStatus(date, 'isha'), PrayerLogStatus.missed);
      expect(await store.getString('prayer_logs_v1'), contains('fajr'));

      await state.setPrayerStatus(date, 'fajr', null);
      expect(state.prayerStatus(date, 'fajr'), isNull);
      expect(state.prayerStatus(date, 'isha'), PrayerLogStatus.missed);
    },
  );

  test('Hijri date correction is bounded and persisted', () async {
    final store = _MemorySettingsStore();
    final state = BangAppState(store);
    await state.setHijriDateAdjustment(-9);

    expect(state.hijriDateAdjustment, -2);
    expect(await store.getInt('hijri_adjustment'), -2);
    expect(
      HijriDate.fromGregorian(
        DateTime(2024, 3, 11),
        dayAdjustment: state.hijriDateAdjustment,
      ).day,
      28,
    );
  });

  testWidgets('home shows city and shared city timetable', (tester) async {
    final state = _createState();
    await state.loadScheduleFor(baghdadNow());
    await tester.pumpWidget(BangApp(state: state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('بانگ'), findsOneWidget);
    expect(find.text('هەولێر'), findsOneWidget);
    expect(find.text('نوێژەکان'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and calendar fit small, standard and tablet layouts', (
    tester,
  ) async {
    final state = _createState();
    await state.loadScheduleFor(baghdadNow());
    for (final size in [
      const Size(320, 568),
      const Size(393, 852),
      const Size(768, 1024),
    ]) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      await tester.pumpWidget(BangApp(state: state));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'home at $size');

      await tester.tap(find.text('ڕۆژژمێر'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'calendar at $size');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('system theme is the initial appearance mode', (tester) async {
    final state = _createState();
    await state.loadScheduleFor(baghdadNow());
    await tester.pumpWidget(BangApp(state: state));

    expect(state.themeMode, ThemeMode.system);
  });
}

BangAppState _createState() {
  final store = _MemorySettingsStore();
  return BangAppState(
    store,
    timetableRepository: PrayerTimetableRepository(
      store: store,
      transport: _FixtureTransport(),
    ),
  );
}

class _FixtureTransport implements TimetableTransport {
  @override
  Future<String> get(Uri uri) async {
    final records = <Map<String, Object>>[];
    final start = DateTime.utc(2024);
    for (var index = 0; index < 366; index++) {
      final date = start.add(Duration(days: index));
      records.add({
        'Date':
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'Fajr': '05:00',
        'Sunrise': '06:00',
        'Dhuhr': '12:00',
        'Asr': '02:00',
        'Maghrib': '05:00',
        'Isha': '06:00',
      });
    }
    return jsonEncode(records);
  }
}

class _MemorySettingsStore implements SettingsStore {
  final Map<String, Object> _values = {};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _values[key] as List<String>?;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
