import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/prayer_schedule.dart';
import '../services/baghdad_clock.dart';
import '../services/localization.dart';
import '../widgets/glass.dart';

String _formatPrayerTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({required this.state, super.key});

  final BangAppState state;

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  late DateTime _date = baghdadDate(baghdadNow());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('تۆماری نوێژ'))),
    body: ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final schedule = widget.state.scheduleFor(_date);
        final prayers = schedule?.obligatory ?? const <PrayerTime>[];
        final recorded = prayers
            .where(
              (prayer) => widget.state.prayerStatus(_date, prayer.id) != null,
            )
            .length;
        final completed = prayers
            .where(
              (prayer) =>
                  widget.state.prayerStatus(_date, prayer.id) ==
                  PrayerLogStatus.completed,
            )
            .length;
        final weekly = _completedInRange(7);
        final monthly = _completedInRange(30);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            GlassSurface(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.text('ڕۆژی پێشوو'),
                    onPressed: () => setState(
                      () => _date = _date.subtract(const Duration(days: 1)),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _date.day == baghdadNow().day &&
                                  _date.month == baghdadNow().month &&
                                  _date.year == baghdadNow().year
                              ? context.l10n.text('ئەمڕۆ')
                              : context.l10n.text('ڕۆژ'),
                        ),
                        Text(
                          '${_date.year}/${_date.month}/${_date.day}',
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.text('ڕۆژی داهاتوو'),
                    onPressed: _isToday
                        ? null
                        : () => setState(
                            () => _date = _date.add(const Duration(days: 1)),
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (schedule == null)
              GlassSurface(
                child: Text(
                  context.l10n.text(
                    'خشتەی ئەم ڕۆژە بەردەست نییە؛ تۆمارکردن ناکرێت.',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              GlassSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(context.l10n.text('ڕۆژانە')),
                        ),
                        Text('$completed / ${prayers.length}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: prayers.isEmpty ? 0 : completed / prayers.length,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.t(
                        '$recorded تۆمارکراو · '
                            '${prayers.length - recorded} نەنووسراو',
                        '$recorded مسجلة · '
                            '${prayers.length - recorded} غير مسجلة',
                        '$recorded recorded · '
                            '${prayers.length - recorded} not recorded',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final prayer in prayers) ...[
                _PrayerLogRow(
                  prayer: prayer,
                  status: widget.state.prayerStatus(_date, prayer.id),
                  onChanged: (status) =>
                      widget.state.setPrayerStatus(_date, prayer.id, status),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: context.l10n.text('٧ ڕۆژ'),
                    value: '$weekly',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: context.l10n.text('٣٠ ڕۆژ'),
                    value: '$monthly',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  bool get _isToday {
    final today = baghdadNow();
    return _date.year == today.year &&
        _date.month == today.month &&
        _date.day == today.day;
  }

  int _completedInRange(int days) {
    var count = 0;
    final today = baghdadDate(baghdadNow());
    for (var offset = 0; offset < days; offset++) {
      final date = today.subtract(Duration(days: offset));
      for (final prayer in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        if (widget.state.prayerStatus(date, prayer) ==
            PrayerLogStatus.completed) {
          count++;
        }
      }
    }
    return count;
  }
}

class _PrayerLogRow extends StatelessWidget {
  const _PrayerLogRow({
    required this.prayer,
    required this.status,
    required this.onChanged,
  });

  final PrayerTime prayer;
  final PrayerLogStatus? status;
  final ValueChanged<PrayerLogStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      PrayerLogStatus.completed => (
        context.l10n.text('ئەنجامدرا'),
        Icons.check_circle_rounded,
        Theme.of(context).colorScheme.primary,
      ),
      PrayerLogStatus.missed => (
        context.l10n.text('لەدەستچوو'),
        Icons.cancel_outlined,
        Theme.of(context).colorScheme.error,
      ),
      null => (
        context.l10n.text('تۆمار نەکراوە'),
        Icons.radio_button_unchecked_rounded,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      radius: 19,
      blur: 6,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.prayerName(prayer.id),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatPrayerTime(prayer.time),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.text('گۆڕینی دۆخ'),
            initialValue: status?.name,
            onSelected: (value) => onChanged(
              value == 'clear'
                  ? null
                  : PrayerLogStatus.values.firstWhere(
                      (item) => item.name == value,
                    ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'completed',
                child: Text(context.l10n.text('ئەنجامدرا')),
              ),
              PopupMenuItem(
                value: 'missed',
                child: Text(context.l10n.text('لەدەستچوو')),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text(context.l10n.text('تۆمار نەکراوە')),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(width: 6),
                  Icon(icon, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => GlassSurface(
    padding: const EdgeInsets.all(14),
    radius: 18,
    blur: 6,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}
