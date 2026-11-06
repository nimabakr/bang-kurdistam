class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const kurdishMonths = [
    'موحەڕەم',
    'سەفەر',
    'ڕەبیعی یەکەم',
    'ڕەبیعی دووەم',
    'جەمادی یەکەم',
    'جەمادی دووەم',
    'ڕەجەب',
    'شەعبان',
    'ڕەمەزان',
    'شەووال',
    'ذولقەعدە',
    'ذولحیججە',
  ];

  static const arabicMonths = [
    'مُحَرَّم',
    'صَفَر',
    'رَبيع الأول',
    'رَبيع الثاني',
    'جُمادى الأولى',
    'جُمادى الآخرة',
    'رَجَب',
    'شَعبان',
    'رَمَضان',
    'شَوّال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const englishMonths = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha‘ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi‘dah',
    'Dhu al-Hijjah',
  ];

  String monthName(String language) => switch (language) {
    'ar' => arabicMonths[month - 1],
    'en' => englishMonths[month - 1],
    _ => kurdishMonths[month - 1],
  };

  static int daysInMonth(int year, int month) {
    final first = _toJulianDay(year, month, 1);
    final next = month == 12
        ? _toJulianDay(year + 1, 1, 1)
        : _toJulianDay(year, month + 1, 1);
    return next - first;
  }

  static DateTime toGregorian(int year, int month, int day) {
    final julianDay = _toJulianDay(year, month, day);
    return DateTime.utc(1970, 1, 1).add(Duration(days: julianDay - 2440588));
  }

  static HijriDate fromGregorian(DateTime date, {int dayAdjustment = 0}) {
    final adjusted = DateTime.utc(
      date.year,
      date.month,
      date.day + dayAdjustment,
    );
    final julianDay =
        adjusted.difference(DateTime.utc(1970, 1, 1)).inDays + 2440588;
    final year = ((30 * (julianDay - 1948440) + 10646) / 10631).floor();
    var month = 1;
    for (var candidate = 2; candidate <= 12; candidate++) {
      if (_toJulianDay(year, candidate, 1) > julianDay) break;
      month = candidate;
    }
    final day = julianDay - _toJulianDay(year, month, 1) + 1;
    return HijriDate(year, month, day);
  }

  static int _toJulianDay(int year, int month, int day) =>
      day +
      (29.5 * (month - 1)).ceil() +
      (year - 1) * 354 +
      ((3 + 11 * year) / 30).floor() +
      1948440 -
      1;
}
