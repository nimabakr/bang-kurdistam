import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../features/app_shell.dart';
import '../services/baghdad_clock.dart';
import '../services/hijri_calendar.dart';
import '../services/localization.dart';
import '../widgets/glass.dart';

class TasbihScreen extends StatelessWidget {
  const TasbihScreen({required this.state, super.key});

  final BangAppState state;

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('ڕێستکردنی ژمارە')),
        content: Text(
          context.l10n.text('دڵنیایت دەتەوێت ژمارەکە سفر بکەیتەوە؟'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('نەخێر')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('بەڵێ، سفر')),
          ),
        ],
      ),
    );
    if (shouldReset == true) await state.setTasbihCount(0);
  }

  Future<void> _chooseCustomTarget(BuildContext context) async {
    final controller = TextEditingController(text: '${state.tasbihTarget}');
    String? validationError;
    final target = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.text('ئامانجی تایبەت')),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.l10n.text('ژمارە'),
              errorText: validationError,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.text('پاشگەزبوونەوە')),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value > 0 && value <= 100000) {
                  Navigator.pop(context, value);
                } else {
                  setDialogState(
                    () => validationError = context.l10n.t(
                      'ژمارەیەکی لە ١ تا ١٠٠٠٠٠ بنووسە.',
                      'أدخل رقمًا من ١ إلى ١٠٠٠٠٠.',
                      'Enter a number from 1 to 100,000.',
                    ),
                  );
                }
              },
              child: Text(context.l10n.text('پاشەکەوت')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (target != null) await state.setTasbihTarget(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('تەسبیحی دیجیتاڵ')),
        actions: [
          IconButton(
            tooltip: context.l10n.text('ڕێستکردن'),
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: state.tasbihDhikr,
                        items: const [
                          DropdownMenuItem(
                            value: 'subhanallah',
                            child: Text('سُبْحَانَ ٱللَّٰهِ'),
                          ),
                          DropdownMenuItem(
                            value: 'alhamdulillah',
                            child: Text('ٱلْحَمْدُ لِلَّٰهِ'),
                          ),
                          DropdownMenuItem(
                            value: 'allahu_akbar',
                            child: Text('ٱللَّٰهُ أَكْبَرُ'),
                          ),
                          DropdownMenuItem(
                            value: 'astaghfirullah',
                            child: Text('أَسْتَغْفِرُ ٱللَّٰهَ'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) state.setTasbihDhikr(value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(context.l10n.text('ئامانج'))),
                      DropdownButton<int>(
                        value:
                            const [
                              33,
                              99,
                              100,
                              1000,
                            ].contains(state.tasbihTarget)
                            ? state.tasbihTarget
                            : 0,
                        items: [
                          DropdownMenuItem(
                            value: 33,
                            child: Text(context.l10n.t('٣٣', '٣٣', '33')),
                          ),
                          DropdownMenuItem(
                            value: 99,
                            child: Text(context.l10n.t('٩٩', '٩٩', '99')),
                          ),
                          DropdownMenuItem(
                            value: 100,
                            child: Text(context.l10n.t('١٠٠', '١٠٠', '100')),
                          ),
                          DropdownMenuItem(
                            value: 1000,
                            child: Text(
                              context.l10n.t('١٠٠٠', '١٠٠٠', '1,000'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              '${context.l10n.text('تایبەت')}${const [33, 99, 100, 1000].contains(state.tasbihTarget) ? '' : ' (${state.tasbihTarget})'}',
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == 0) {
                            _chooseCustomTarget(context);
                          } else if (value != null) {
                            state.setTasbihTarget(value);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: context.l10n.text('ئامانجی تایبەت'),
                        onPressed: () => _chooseCustomTarget(context),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: context.l10n.t(
                      'زیادکردنی ژمارەی ${state.tasbihDhikr}',
                      'إضافة إلى ${state.tasbihDhikr}',
                      'Add to ${state.tasbihDhikr}',
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (state.tasbihHapticsEnabled) {
                            HapticFeedback.selectionClick();
                          }
                          state.setTasbihCount(state.tasbihCount + 1);
                        },
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F8068), Color(0xFF0B4034)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFD8B46A),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0B4034)
                                    .withValues(alpha: .28),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${state.tasbihCount}',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${state.tasbihCount} / ${state.tasbihTarget}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (state.tasbihCount / state.tasbihTarget)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: state.tasbihCount == 0
                        ? null
                        : () => state.setTasbihCount(state.tasbihCount - 1),
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(context.l10n.text('یەک هەنگاو پاشەوە')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.text(
                      'ژمارەکە لەسەر ئامێرەکەت پاشەکەوت دەکرێت.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({required this.state, super.key});

  final BangAppState state;

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  late DateTime _month = DateTime.utc(baghdadNow().year, baghdadNow().month);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final today = baghdadNow();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('ڕۆژژمێری مانگانە'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.text('مانگی پێشوو'),
                  onPressed: () => setState(
                    () => _month = DateTime.utc(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Text(
                    '${context.l10n.gregorianMonth(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.text('مانگی داهاتوو'),
                  onPressed: () => setState(
                    () => _month = DateTime.utc(_month.year, _month.month + 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _CalendarColumnHeader(context.l10n.text('ڕۆژ')),
                _CalendarColumnHeader(context.l10n.prayerName('fajr')),
                _CalendarColumnHeader(context.l10n.prayerName('sunrise')),
                _CalendarColumnHeader(context.l10n.prayerName('dhuhr')),
                _CalendarColumnHeader(context.l10n.prayerName('asr')),
                _CalendarColumnHeader(context.l10n.prayerName('maghrib')),
                _CalendarColumnHeader(context.l10n.prayerName('isha')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime.utc(_month.year, _month.month, index + 1);
                final schedule = widget.state.scheduleFor(date);
                final byId = {
                  for (final prayer in schedule?.times ?? const [])
                    prayer.id: prayer,
                };
                final isToday =
                    today.year == date.year &&
                    today.month == date.month &&
                    today.day == date.day;
                final values = [
                  '${date.day}',
                  byId['fajr'] == null ? '—' : formatTime(byId['fajr']!.time),
                  byId['sunrise'] == null
                      ? '—'
                      : formatTime(byId['sunrise']!.time),
                  byId['dhuhr'] == null ? '—' : formatTime(byId['dhuhr']!.time),
                  byId['asr'] == null ? '—' : formatTime(byId['asr']!.time),
                  byId['maghrib'] == null
                      ? '—'
                      : formatTime(byId['maghrib']!.time),
                  byId['isha'] == null ? '—' : formatTime(byId['isha']!.time),
                ];
                return Container(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                            .withValues(alpha: .1)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: Text(
                            values[i],
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: isToday ? FontWeight.w800 : null,
                                  color: i == 0
                                      ? Theme.of(context).colorScheme.onSurface
                                      : null,
                                ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CalendarColumnHeader extends StatelessWidget {
  const _CalendarColumnHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({required this.state, super.key});

  final BangAppState state;

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late HijriDate _month = HijriDate.fromGregorian(baghdadNow());

  void _moveMonth(int amount) {
    var month = _month.month + amount;
    var year = _month.year;
    if (month < 1) {
      year--;
      month = 12;
    } else if (month > 12) {
      year++;
      month = 1;
    }
    setState(() => _month = HijriDate(year, month, 1));
  }

  @override
  Widget build(BuildContext context) {
    final today = HijriDate.fromGregorian(
      baghdadNow(),
      dayAdjustment: widget.state.hijriDateAdjustment,
    );
    final days = HijriDate.daysInMonth(_month.year, _month.month);
    final firstGregorian = HijriDate.toGregorian(_month.year, _month.month, 1);
    final offset = firstGregorian.weekday % 7;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('ڕۆژژمێری هیجری'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
        children: [
          GlassSurface(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.text('مانگی پێشوو'),
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_month.monthName(context.l10n.language.code)} '
                    '${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.text('مانگی داهاتوو'),
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            children: [
              for (final day in switch (context.l10n.language) {
                AppLanguage.ku => const ['ی', 'د', 'س', 'چ', 'پ', 'ه', 'ش'],
                AppLanguage.ar => const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'],
                AppLanguage.en => const ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
              })
                _HijriWeekday(day),
            ],
          ),
          const SizedBox(height: 6),
          GlassSurface(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > days) return const SizedBox.shrink();
                final isToday =
                    today.year == _month.year &&
                    today.month == _month.month &&
                    today.day == day;
                final gregorian = HijriDate.toGregorian(
                  _month.year,
                  _month.month,
                  day,
                );
                return Tooltip(
                  message:
                      '${gregorian.year}/${gregorian.month}/${gregorian.day}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                                .withValues(alpha: .22)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.w800 : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.text(
              'بەرواری هیجریی خەمڵێنراوە؛ ڕۆژبژمێری مانگ‌بینینی ناوخۆیی لەوانەیە جیاواز بێت.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HijriWeekday extends StatelessWidget {
  const _HijriWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 40, child: Text(label, textAlign: TextAlign.center));
}
