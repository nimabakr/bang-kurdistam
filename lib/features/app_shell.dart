import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../domain/city.dart';
import '../domain/prayer_schedule.dart';
import '../screens/city_picker.dart';
import '../screens/prayer_tracker_screen.dart';
import '../screens/utility_screens.dart';
import '../services/baghdad_clock.dart';
import '../services/hijri_calendar.dart';
import '../services/localization.dart';
import '../services/prayer_notifications.dart';
import '../widgets/glass.dart';

const _gold = Color(0xFFD8B46A);
const _deepGreen = Color(0xFF0C3329);

String formatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String formatCountdown(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours.toString().padLeft(2, '0');
  final minutes = safeDuration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final seconds = safeDuration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class AppShell extends StatefulWidget {
  const AppShell({required this.state, super.key});

  final BangAppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _PrayerNotificationLifecycle(
        onResumed: () {
          widget.state.refreshPrayerNotifications();
        },
      );

  void _openCityPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: CityPickerScreen(state: widget.state),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsScreen(state: widget.state, onChooseCity: _openCityPicker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final pages = <Widget>[
      HomeScreen(
        state: state,
        onChooseCity: _openCityPicker,
        onOpenSettings: _openSettings,
      ),
      MonthlyCalendarScreen(state: state),
      MoreScreen(state: state, onOpenSettings: _openSettings),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: NavigationBar(
              height: 66,
              backgroundColor: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .74),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: context.l10n.text('سەرەکی'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: context.l10n.text('ڕۆژژمێر'),
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  label: context.l10n.text('زیاتر'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.state,
    required this.onChooseCity,
    required this.onOpenSettings,
    super.key,
  });

  final BangAppState state;
  final VoidCallback onChooseCity;
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;
  DateTime _now = baghdadNow();
  DateTime? _loadedDate;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_refresh);
    _loadedDate = _now;
    if (widget.state.todaySchedule == null && !widget.state.scheduleLoading) {
      unawaited(widget.state.loadScheduleFor(_now));
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = baghdadNow();
      if (_isDifferentDay(_loadedDate, now)) {
        _loadedDate = now;
        unawaited(widget.state.loadScheduleFor(now));
      }
      setState(() => _now = now);
    });
  }

  bool _isDifferentDay(DateTime? first, DateTime second) =>
      first == null ||
      first.year != second.year ||
      first.month != second.month ||
      first.day != second.day;

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_refresh);
      widget.state.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    widget.state.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final schedule = state.scheduleFor(_now);
    final tomorrow = state.scheduleFor(_now.add(const Duration(days: 1)));
    final next = PrayerSchedule.nextAfter(
      today: schedule,
      tomorrow: tomorrow,
      now: _now,
    );
    final previous = _previousPrayer(schedule, _now);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(
                city: state.selectedCity,
                onChooseCity: widget.onChooseCity,
                onOpenSettings: widget.onOpenSettings,
              ),
              const SizedBox(height: 12),
              _DateLine(date: _now, hijriAdjustment: state.hijriDateAdjustment),
              const SizedBox(height: 16),
              if (next != null)
                _NextPrayerCard(
                  prayer: next,
                  remaining: next.time.difference(_now),
                  progress: _prayerProgress(previous, next, _now),
                )
              else
                SizedBox(height: 160, child: _ScheduleStatus(state: state)),
              if (schedule != null) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      context.l10n.text('نوێژەکان'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _SourcePill(schedule: schedule),
                  ],
                ),
                const SizedBox(height: 6),
                _PrayerList(schedule: schedule, nextPrayerId: next?.id),
                const SizedBox(height: 5),
                _SunriseLine(
                  prayer: schedule.times.firstWhere(
                    (prayer) => prayer.isSunrise,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.city,
    required this.onChooseCity,
    required this.onOpenSettings,
  });

  final City city;
  final VoidCallback onChooseCity;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.nightlight_round, color: _gold, size: 23),
      ),
      const SizedBox(width: 6),
      Text(
        context.l10n.t('بانگ', 'بانگ', 'Bang'),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: TextButton.icon(
          onPressed: onChooseCity,
          icon: const Icon(Icons.location_on_outlined, size: 17),
          label: Text(
            context.l10n.cityName(city),
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 40),
          ),
        ),
      ),
      IconButton(
        tooltip: context.l10n.text('ڕێکخستن'),
        onPressed: onOpenSettings,
        icon: const Icon(Icons.tune_rounded),
      ),
    ],
  );
}

class _DateLine extends StatelessWidget {
  const _DateLine({required this.date, required this.hijriAdjustment});

  final DateTime date;
  final int hijriAdjustment;

  @override
  Widget build(BuildContext context) {
    final hijri = HijriDate.fromGregorian(date, dayAdjustment: hijriAdjustment);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.l10n.weekday(date.weekday)} · '
          '${date.day}/${date.month}/${date.year}',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          '${hijri.day} ${hijri.monthName(context.l10n.language.code)} '
          '${hijri.year} · ${context.l10n.text('هیجری خەمڵێنراو')}',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.prayer,
    required this.remaining,
    required this.progress,
  });

  final PrayerTime prayer;
  final Duration remaining;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
    decoration: BoxDecoration(
      color: _deepGreen,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: _deepGreen.withValues(alpha: .16),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('نوێژی داهاتوو'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white.withValues(alpha: .72)),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                context.l10n.prayerName(prayer.id),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              formatTime(prayer.time),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: _gold, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          formatCountdown(remaining),
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: Colors.white.withValues(alpha: .16),
            color: _gold,
          ),
        ),
      ],
    ),
  );
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({required this.schedule, required this.nextPrayerId});

  final PrayerSchedule schedule;
  final String? nextPrayerId;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var index = 0; index < schedule.obligatory.length; index++) ...[
          _PrayerRow(
            prayer: schedule.obligatory[index],
            isNext: schedule.obligatory[index].id == nextPrayerId,
          ),
          if (index != schedule.obligatory.length - 1)
            Divider(
              height: 1,
              indent: 18,
              endIndent: 18,
              color: Theme.of(context).colorScheme.outlineVariant
                  .withValues(alpha: .45),
            ),
        ],
      ],
    ),
  );
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.prayer, required this.isNext});

  final PrayerTime prayer;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final color = isNext
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label:
          '${context.l10n.prayerName(prayer.id)}, ${formatTime(prayer.time)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 7,
              color: isNext ? _gold : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.prayerName(prayer.id),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isNext ? FontWeight.w700 : null,
                ),
              ),
            ),
            Text(
              formatTime(prayer.time),
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: isNext ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunriseLine extends StatelessWidget {
  const _SunriseLine({required this.prayer});

  final PrayerTime prayer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
    child: Row(
      children: [
        Icon(
          Icons.wb_sunny_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.text('هەڵاتنی خۆر'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          formatTime(prayer.time),
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _ScheduleStatus extends StatelessWidget {
  const _ScheduleStatus({required this.state});

  final BangAppState state;

  @override
  Widget build(BuildContext context) {
    if (state.scheduleLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.scheduleError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.text('کات بەردەست نییە')),
            TextButton(
              onPressed: () => state.loadScheduleFor(baghdadNow()),
              child: Text(context.l10n.text('دووبارە هەوڵبدەوە')),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.schedule});

  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final calculated =
        schedule.source == PrayerScheduleSource.calculatedFallback;
    final cached = schedule.source == PrayerScheduleSource.cachedCityTimetable;
    return Text(
      calculated
          ? context.l10n.text('هەژمارکراو')
          : cached
          ? context.l10n.text('ئۆفلاین')
          : context.l10n.text('خشتەی شار'),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: calculated
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

PrayerTime? _previousPrayer(PrayerSchedule? today, DateTime now) {
  for (final prayer in (today?.obligatory ?? const <PrayerTime>[]).reversed) {
    if (!prayer.time.isAfter(now)) return prayer;
  }
  return null;
}

double _prayerProgress(PrayerTime? previous, PrayerTime next, DateTime now) {
  if (previous == null) return 0;
  final total = next.time.difference(previous.time).inSeconds;
  if (total <= 0) return 0;
  return (now.difference(previous.time).inSeconds / total)
      .clamp(0, 1)
      .toDouble();
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.state,
    required this.onOpenSettings,
    super.key,
  });

  final BangAppState state;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('زیاتر'))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        _MoreTile(
          icon: Icons.radio_button_checked_rounded,
          title: context.l10n.text('تەسبیح'),
          onTap: () => _push(context, TasbihScreen(state: state)),
        ),
        _MoreTile(
          icon: Icons.schedule_rounded,
          title: context.l10n.text('کاتەکانی نوێژ'),
          onTap: () => _push(context, PrayerTimesScreen(state: state)),
        ),
        _MoreTile(
          icon: Icons.fact_check_outlined,
          title: context.l10n.text('تۆماری نوێژ'),
          onTap: () => _push(context, PrayerTrackerScreen(state: state)),
        ),
        _MoreTile(
          icon: Icons.calendar_month_rounded,
          title: context.l10n.text('ڕۆژژمێری هیجری'),
          onTap: () => _push(context, HijriCalendarScreen(state: state)),
        ),
        _MoreTile(
          icon: Icons.tune_rounded,
          title: context.l10n.text('ڕێکخستن'),
          onTap: onOpenSettings,
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Bang | Kurdistan', style: TextStyle(color: Colors.grey)),
        ),
      ],
    ),
  );
}

class _PrayerNotificationLifecycle with WidgetsBindingObserver {
  _PrayerNotificationLifecycle({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GlassSurface(
      padding: EdgeInsets.zero,
      radius: 20,
      blur: 7,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    ),
  );
}

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({required this.state, super.key});

  final BangAppState state;

  @override
  Widget build(BuildContext context) {
    final schedule = state.scheduleFor(baghdadNow());
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('کاتەکانی نوێژ'))),
      body: schedule == null
          ? _ScheduleStatus(state: state)
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  context.l10n.cityName(state.selectedCity),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _SourcePill(schedule: schedule),
                const SizedBox(height: 10),
                _PrayerList(
                  schedule: schedule,
                  nextPrayerId: PrayerSchedule.nextAfter(
                    today: schedule,
                    tomorrow: state.scheduleFor(
                      baghdadNow().add(const Duration(days: 1)),
                    ),
                    now: baghdadNow(),
                  )?.id,
                ),
              ],
            ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.state,
    required this.onChooseCity,
    super.key,
  });

  final BangAppState state;
  final VoidCallback onChooseCity;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('ڕێکخستن'))),
    body: ListenableBuilder(
      listenable: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          _SettingsSection(
            title: context.l10n.text('ڕووکار'),
            children: [
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(context.l10n.text('سیستەم')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(context.l10n.text('ڕووناک')),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(context.l10n.text('تاریک')),
                  ),
                ],
                selected: {state.themeMode},
                onSelectionChanged: (value) => state.setThemeMode(value.first),
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('زمان'),
            children: [
              SegmentedButton<AppLanguage>(
                segments: [
                  ButtonSegment(
                    value: AppLanguage.ku,
                    label: Text(context.l10n.text('کوردی')),
                  ),
                  ButtonSegment(
                    value: AppLanguage.ar,
                    label: Text(context.l10n.text('عەرەبی')),
                  ),
                  ButtonSegment(value: AppLanguage.en, label: Text('English')),
                ],
                selected: {state.appLanguage},
                onSelectionChanged: (value) =>
                    state.setAppLanguage(value.first),
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('شوێن'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(context.l10n.cityName(state.selectedCity)),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: onChooseCity,
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('کاتەکان'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.text('کاتی حیسابکراو')),
                value: state.calculatedFallbackEnabled,
                onChanged: state.setCalculatedFallbackEnabled,
              ),
              for (final prayer in const [
                'fajr',
                'dhuhr',
                'asr',
                'maghrib',
                'isha',
              ])
                _AdjustmentRow(
                  label: context.l10n.prayerName(prayer),
                  value: state.minuteAdjustments[prayer] ?? 0,
                  onChanged: (value) => state.setMinuteAdjustment(prayer, value),
                ),
              _AdjustmentRow(
                label: context.l10n.text('ڕاستکردنەوەی هیجری'),
                value: state.hijriDateAdjustment,
                onChanged: state.setHijriDateAdjustment,
                suffix: 'ڕۆژ',
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('تەسبیح'),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.text('لێدان')),
                value: state.tasbihHapticsEnabled,
                onChanged: state.setTasbihHapticsEnabled,
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('ئاگادارکردنەوەی نوێژ'),
            children: [
              if (!state.notificationsSupported)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text(
                    context.l10n.text('لە وێب نۆتیفیکەیشن چالاک نییە'),
                  ),
                  subtitle: Text(
                    context.l10n.text('لە ئەپی Android یان iOS بەردەستە'),
                  ),
                )
              else ...[
                for (final prayer in const [
                  'fajr',
                  'sunrise',
                  'dhuhr',
                  'asr',
                  'maghrib',
                  'isha',
                ]) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.prayerName(prayer)),
                    value: state.prayerNotificationsEnabled[prayer] ?? false,
                    onChanged: (value) =>
                        state.setPrayerNotificationsEnabled(prayer, value),
                  ),
                  if (state.prayerNotificationsEnabled[prayer] == true)
                    SwitchListTile(
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 22,
                      ),
                      title: Text(context.l10n.text('ئاگادارکردنەوە پێش کات')),
                      value: state.prayerRemindersEnabled[prayer] ?? false,
                      onChanged: (value) =>
                          state.setPrayerReminderEnabled(prayer, value),
                    ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.text('پێشوەختە')),
                  trailing: DropdownButton<int>(
                    value: state.prayerReminderMinutes,
                    items: const [5, 10, 15, 30]
                        .map(
                          (minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text(
                              context.l10n.t(
                                '$minutes خولەک',
                                '$minutes دقيقة',
                                '$minutes min',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (minutes) {
                      if (minutes != null) {
                        state.setPrayerReminderMinutes(minutes);
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.text('لەرزین')),
                  value: state.notificationVibrationEnabled,
                  onChanged: state.setNotificationVibration,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.text('بێدەنگ')),
                  value: state.notificationsSilent,
                  onChanged: state.setNotificationsSilent,
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _testNotification(context),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(context.l10n.text('تاقیکردنەوە')),
                  ),
                ),
                if (state.notificationError case final error?)
                  Text(
                    context.l10n.text(error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('تایبەتمەندی'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text(
                  context.l10n.text('داتاکانت تەنها لەسەر ئامێرەکەتە'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(context.l10n.text('سڕینەوەی داتای کەسی')),
                onTap: () => _confirmClearData(context),
              ),
            ],
          ),
          _SettingsSection(
            title: context.l10n.text('سەرچاوە'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded),
                title: Text(context.l10n.text('خشتەی بانگ | Kurdistan')),
                subtitle: Text(
                  context.l10n.text('داتای لایەنی سێیەم · حکومی نییە'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmClearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('سڕینەوەی داتا')),
        content: Text(
          context.l10n.text('ژمارە، ڕاستکردنەوە و دڵخوازەکان دەسڕدرێنەوە.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('پاشگەزبوونەوە')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('بسڕەوە')),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.clearPersonalData();
  }

  Future<void> _testNotification(BuildContext context) async {
    try {
      await state.sendTestNotification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text('نۆتیفیکەیشنی تاقیکردنەوە نێردرا'),
            ),
          ),
        );
      }
    } on NotificationPermissionDeniedException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.notificationPermissionDenied,
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(
                'نەتوانرا نۆتیفیکەیشن بنێردرێت: ${error.message}',
              ),
            ),
          ),
        );
      }
    } on MissingPluginException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text('خزمەتگوزاری بەردەست نییە: ${error.message}'),
            ),
          ),
        );
      }
    } on UnsupportedError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text(error.message ?? 'پشتگیری ناکرێت'),
            ),
          ),
        );
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(content: Text(context.l10n.text(error.message))),
            );
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: 4,
            bottom: 5,
            top: 4,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    ),
  );
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix = 'خۆڵەکە',
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: context.l10n.text('کەمکردنەوە'),
        onPressed: () => onChanged((value - 1).clamp(-60, 60).toInt()),
        icon: const Icon(Icons.remove_circle_outline, size: 20),
      ),
      Text('$value ${context.l10n.text(suffix)}'),
      IconButton(
        tooltip: context.l10n.text('زیادکردن'),
        onPressed: () => onChanged((value + 1).clamp(-60, 60).toInt()),
        icon: const Icon(Icons.add_circle_outline, size: 20),
      ),
    ],
  );
}
