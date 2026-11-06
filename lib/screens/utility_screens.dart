import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../app_state.dart';
import '../services/qibla_service.dart';
import '../features/app_shell.dart';
import '../services/baghdad_clock.dart';
import '../services/hijri_calendar.dart';
import '../widgets/glass.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({required this.state, super.key});

  final BangAppState state;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  double? _deviceHeading;
  final _manualHeadingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenToCompass();
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _manualHeadingController.dispose();
    super.dispose();
  }

  void _listenToCompass() {
    _magnetometerSubscription = magnetometerEventStream().listen(
      (event) {
        final heading = QiblaService.headingFromMagnetometer(event);
        if (heading == null || !mounted) return;
        setState(() => _deviceHeading = heading);
      },
      onError: (_) {
        if (mounted) setState(() => _deviceHeading = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.state.selectedCity;
    final latitude = city.latitude;
    final longitude = city.longitude;
    if (latitude == null || longitude == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('قیبلە')),
        body: const Center(child: Text('شوێنی قیبلە بەردەست نییە')),
      );
    }

    final qiblaBearing = QiblaService.bearingFrom(city);
    final distance = _distanceToKaaba(latitude, longitude);
    final manualDegree = double.tryParse(_manualHeadingController.text) ?? 0;
    final heading = _deviceHeading ?? manualDegree;
    final relative = QiblaService.relativeBearing(
      qiblaBearing: qiblaBearing,
      heading: heading,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('قیبلە')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          Text(city.kurdishName, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: .12),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  ..._cardinalMarkers(),
                  Transform.rotate(
                    angle: relative * math.pi / 180,
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(
                        painter: _CompassPointerPainter(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mosque_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${qiblaBearing.toStringAsFixed(1)}°',
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${distance.toStringAsFixed(0)} km',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_deviceHeading == null)
            Text(
              'کۆمپاسەکە بەردەست نییە؛ هەڵبژاردنی دەستی لەژێر بەردەستە.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Text(
              'ڕووی کۆمپاس: ${_deviceHeading!.toStringAsFixed(1)}°',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualHeadingController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            decoration: InputDecoration(
              labelText: 'ڕووی دەستی (درێژە)',
              hintText: '0 - 359',
              suffixText: '°',
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed == null) return;
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              final parsed = double.tryParse(_manualHeadingController.text);
              if (parsed == null) {
                _manualHeadingController.text = '0';
              }
              setState(() {});
            },
            icon: const Icon(Icons.rotate_left_rounded),
            label: const Text('ڕێکخستنی دەستی'),
          ),
        ],
      ),
    );
  }

  List<Widget> _cardinalMarkers() {
    return const [
      Positioned(top: 18, child: Text('N')),
      Positioned(bottom: 18, child: Text('S')),
      Positioned(left: 20, child: Text('E')),
      Positioned(right: 20, child: Text('W')),
    ];
  }

  static double _distanceToKaaba(double latitude, double longitude) {
    const earthRadiusKm = 6371.0;
    const kaabaLatitude = 21.4225241;
    const kaabaLongitude = 39.8261818;
    final latitudeDelta = _radians(kaabaLatitude - latitude);
    final longitudeDelta = _radians(kaabaLongitude - longitude);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_radians(latitude)) *
            math.cos(_radians(kaabaLatitude)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double value) => value * math.pi / 180;
}

class _CompassPointerPainter extends CustomPainter {
  const _CompassPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.32)
      ..lineTo(center.dx - 12, center.dy + size.height * 0.18)
      ..lineTo(center.dx + 12, center.dy + size.height * 0.18)
      ..close();
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, fill);
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.22),
      Offset(center.dx, center.dy + size.height * 0.26),
      line,
    );
  }

  @override
  bool shouldRepaint(_CompassPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class TasbihScreen extends StatelessWidget {
  const TasbihScreen({required this.state, super.key});

  final BangAppState state;

  Future<void> _confirmReset(BuildContext context) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ڕێستکردنی ژمارە'),
        content: const Text('دڵنیایت دەتەوێت ژمارەکە سفر بکەیتەوە؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('نەخێر'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بەڵێ، سفر'),
          ),
        ],
      ),
    );
    if (shouldReset == true) await state.setTasbihCount(0);
  }

  Future<void> _chooseCustomTarget(BuildContext context) async {
    final controller = TextEditingController(text: '${state.tasbihTarget}');
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ئامانجی تایبەت'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'ژمارە'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پاشگەزبوونەوە'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0 && value <= 100000) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('پاشەکەوت'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target != null) await state.setTasbihTarget(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تەسبیحی دیجیتاڵ'),
        actions: [
          IconButton(
            tooltip: 'ڕێستکردن',
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
                      const Expanded(child: Text('ئامانج')),
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
                          const DropdownMenuItem(value: 33, child: Text('٣٣')),
                          const DropdownMenuItem(value: 99, child: Text('٩٩')),
                          const DropdownMenuItem(
                            value: 100,
                            child: Text('١٠٠'),
                          ),
                          const DropdownMenuItem(
                            value: 1000,
                            child: Text('١٠٠٠'),
                          ),
                          DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'تایبەت${const [33, 99, 100, 1000].contains(state.tasbihTarget) ? '' : ' (${state.tasbihTarget})'}',
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
                        tooltip: 'ئامانجی تایبەت',
                        onPressed: () => _chooseCustomTarget(context),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'زیادکردنی ژمارەی ${state.tasbihDhikr}',
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
                    label: const Text('یەک هەنگاو پاشەوە'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ژمارەکە لەسەر ئامێرەکەت پاشەکەوت دەکرێت.',
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

  static const _monthNames = [
    'کانوونی دووەم',
    'شوبات',
    'ئازار',
    'نیسان',
    'ئایار',
    'حوزەیران',
    'تەممووز',
    'ئاب',
    'ئەیلوول',
    'تشرینی یەکەم',
    'تشرینی دووەم',
    'کانوونی یەکەم',
  ];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final today = baghdadNow();
    return Scaffold(
      appBar: AppBar(title: const Text('ڕۆژژمێری مانگانە')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'مانگی پێشوو',
                  onPressed: () => setState(
                    () => _month = DateTime.utc(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'مانگی داهاتوو',
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
              children: const [
                _CalendarColumnHeader('ڕۆژ'),
                _CalendarColumnHeader('بەیانی'),
                _CalendarColumnHeader('هەڵاتن'),
                _CalendarColumnHeader('نیوەڕۆ'),
                _CalendarColumnHeader('عەسر'),
                _CalendarColumnHeader('ئێوارە'),
                _CalendarColumnHeader('خەوتن'),
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
      appBar: AppBar(title: const Text('ڕۆژژمێری هیجری')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
        children: [
          GlassSurface(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'مانگی پێشوو',
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_month.monthName('ku')} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'مانگی داهاتوو',
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            alignment: WrapAlignment.spaceAround,
            children: [
              _HijriWeekday('ی'),
              _HijriWeekday('د'),
              _HijriWeekday('س'),
              _HijriWeekday('چ'),
              _HijriWeekday('پ'),
              _HijriWeekday('ه'),
              _HijriWeekday('ش'),
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
            'بەرواری هیجریی خەمڵێنراوە؛ ڕۆژبژمێری مانگ‌بینینی ناوخۆیی لەوانەیە جیاواز بێت.',
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
