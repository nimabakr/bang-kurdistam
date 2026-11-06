import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/city.dart';

enum AppLanguage { ku, ar, en }

extension AppLanguageX on AppLanguage {
  String get code => switch (this) {
    AppLanguage.ku => 'ku',
    AppLanguage.ar => 'ar',
    AppLanguage.en => 'en',
  };

  String get label => switch (this) {
    AppLanguage.ku => 'کوردی',
    AppLanguage.ar => 'العربية',
    AppLanguage.en => 'English',
  };
}

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String t(String ku, String ar, String en) => switch (language) {
    AppLanguage.ku => ku,
    AppLanguage.ar => ar,
    AppLanguage.en => en,
  };

  String text(String sorani) {
    if (language == AppLanguage.ku) return sorani;
    final translation = switch (language) {
      AppLanguage.ku => null,
      AppLanguage.ar => _arabic[sorani],
      AppLanguage.en => _english[sorani],
    };
    if (translation != null) return translation;

    for (final entry in _dynamicPrefixes.entries) {
      if (sorani.startsWith(entry.key)) {
        return '${language == AppLanguage.ar ? entry.value.$1 : entry.value.$2}'
            '${sorani.substring(entry.key.length)}';
      }
    }
    return sorani;
  }

  String cityName(City city) => switch (language) {
    AppLanguage.ku => city.kurdishName,
    AppLanguage.ar => city.arabicName,
    AppLanguage.en => city.englishName,
  };

  String prayerName(String id) => switch (id) {
    'fajr' => text('بەیانی'),
    'sunrise' => text('هەڵاتنی خۆر'),
    'dhuhr' => text('نیوەڕۆ'),
    'asr' => text('عەسر'),
    'maghrib' => text('ئێوارە'),
    'isha' => text('خەوتنان'),
    _ => t('نوێژ', 'الصلاة', 'Prayer'),
  };

  String weekday(int weekday) => _weekdays[language]![weekday - 1];

  String gregorianMonth(int month) => _gregorianMonths[language]![month - 1];

  String reminderBody(int minutes) => t(
    'ماوەی $minutes خولەک بۆ بانگ',
    'بقي $minutes دقيقة على الصلاة',
    '$minutes minutes until prayer',
  );

  String prayerNotificationBody() =>
      t('کاتی بانگی نوێژە', 'حان الآن وقت الصلاة', 'It is prayer time');

  String testNotificationBody() => t(
    'نۆتیفیکەیشنی تاقیکردنەوە',
    'هذا إشعار تجريبي',
    'This is a test notification',
  );

  String notificationTitle(String prayerId) => t(
    'بانگی ${prayerName(prayerId)}',
    'حان وقت صلاة ${prayerName(prayerId)}',
    '${prayerName(prayerId)} prayer',
  );

  String get notificationPermissionDenied => t(
    'مۆڵەتی نۆتیفیکەیشن نەدراوە؛ لە ڕێکخستنەکانی ئامێرەکەت چالاکی بکە.',
    'لم يُمنح إذن الإشعارات؛ فعّله من إعدادات جهازك.',
    'Notification permission was denied. Enable it in your device settings.',
  );
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate(this.language);

  final AppLanguage language;

  @override
  bool isSupported(Locale locale) => AppLanguage.values.any(
    (language) => language.code == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(language));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => old.language != language;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

const _dynamicPrefixes = <String, (String, String)>{
  'نۆتیفیکەیشن نەتوانرا دەستپێبکرێت: ': (
    'تعذر تهيئة الإشعارات: ',
    'Could not initialize notifications: ',
  ),
  'خزمەتی نۆتیفیکەیشن بەردەست نییە: ': (
    'خدمة الإشعارات غير متاحة: ',
    'Notification service is unavailable: ',
  ),
  'نۆتیفیکەیشن نەتوانرا نوێ بکرێتەوە: ': (
    'تعذر تحديث الإشعارات: ',
    'Could not refresh notifications: ',
  ),
  'مۆڵەتی نۆتیفیکەیشن وەرنەگیرا: ': (
    'تعذر طلب إذن الإشعارات: ',
    'Could not request notification permission: ',
  ),
  'نەتوانرا نۆتیفیکەیشن بنێردرێت: ': (
    'تعذر إرسال الإشعار: ',
    'Could not send notification: ',
  ),
  'خزمەتگوزاری بەردەست نییە: ': ('الخدمة غير متاحة: ', 'Service unavailable: '),
};

const _arabic = <String, String>{
  'سەرەکی': 'الرئيسية',
  'ڕۆژژمێر': 'التقويم',
  'زیاتر': 'المزيد',
  'نوێژەکان': 'الصلوات',
  'ڕێکخستن': 'الإعدادات',
  'دووشەممە': 'الاثنين',
  'سێشەممە': 'الثلاثاء',
  'چوارشەممە': 'الأربعاء',
  'پێنجشەممە': 'الخميس',
  'هەینی': 'الجمعة',
  'شەممە': 'السبت',
  'یەکشەممە': 'الأحد',
  'هیجری خەمڵێنراو': 'هجري تقريبي',
  'نوێژی داهاتوو': 'الصلاة القادمة',
  'هەڵاتنی خۆر': 'الشروق',
  'کات بەردەست نییە': 'الوقت غير متاح',
  'دووبارە هەوڵبدەوە': 'حاول مرة أخرى',
  'هەژمارکراو': 'محسوب',
  'ئۆفلاین': 'دون اتصال',
  'خشتەی شار': 'جدول المدينة',
  'تەسبیح': 'التسبيح',
  'کاتەکانی نوێژ': 'مواقيت الصلاة',
  'تۆماری نوێژ': 'سجل الصلاة',
  'ڕۆژژمێری هیجری': 'التقويم الهجري',
  'ڕووکار': 'المظهر',
  'سیستەم': 'النظام',
  'ڕووناک': 'فاتح',
  'تاریک': 'داكن',
  'زمان': 'اللغة',
  'کوردی': 'الكردية',
  'عەرەبی': 'العربية',
  'شوێن': 'الموقع',
  'کاتەکان': 'المواقيت',
  'کاتی حیسابکراو': 'المواقيت المحسوبة',
  'بەیانی': 'الفجر',
  'نیوەڕۆ': 'الظهر',
  'عەسر': 'العصر',
  'ئێوارە': 'المغرب',
  'خەوتنان': 'العشاء',
  'ڕاستکردنەوەی هیجری': 'تعديل التاريخ الهجري',
  'ڕۆژ': 'يوم',
  'لێدان': 'الاهتزاز',
  'ئاگادارکردنەوەی نوێژ': 'تنبيهات الصلاة',
  'لە وێب نۆتیفیکەیشن چالاک نییە': 'الإشعارات غير متاحة على الويب',
  'لە ئەپی Android یان iOS بەردەستە': 'متاحة على Android وiOS',
  'مۆڵەتی نۆتیفیکەیشن نەدراوە؛ لە ڕێکخستنەکانی ئامێرەکەت چالاکی بکە.':
      'لم يُمنح إذن الإشعارات؛ فعّله من إعدادات جهازك.',
  'نۆتیفیکەیشن لەم پلاتفۆرمەدا پشتگیری ناکرێت.':
      'الإشعارات غير مدعومة على هذه المنصة.',
  'نۆتیفیکەیشن لەم پلاتفۆرمەدا بەردەست نییە.':
      'الإشعارات غير متاحة على هذه المنصة.',
  'ئاگادارکردنەوە پێش کات': 'تذكير قبل الموعد',
  'پێشوەختە': 'قبل الموعد',
  'لەرزین': 'الاهتزاز',
  'بێدەنگ': 'صامت',
  'تاقیکردنەوە': 'اختبار الإشعار',
  'تایبەتمەندی': 'الخصوصية',
  'داتاکانت تەنها لەسەر ئامێرەکەتە': 'بياناتك محفوظة على جهازك فقط',
  'سڕینەوەی داتای کەسی': 'مسح البيانات الشخصية',
  'سەرچاوە': 'المصدر',
  'خشتەی بانگ | Kurdistan': 'جدول بانگ | Kurdistan',
  'داتای لایەنی سێیەم · حکومی نییە': 'بيانات من جهة خارجية · غير حكومية',
  'سڕینەوەی داتا': 'مسح البيانات',
  'ژمارە، ڕاستکردنەوە و دڵخوازەکان دەسڕدرێنەوە.':
      'سيتم مسح العدّادات والتعديلات والمفضلة.',
  'پاشگەزبوونەوە': 'إلغاء',
  'بسڕەوە': 'امسح',
  'نۆتیفیکەیشنی تاقیکردنەوە نێردرا': 'تم إرسال إشعار الاختبار',
  'نەتوانرا نۆتیفیکەیشن بنێردرێت: ': 'تعذر إرسال الإشعار: ',
  'خزمەتگوزاری بەردەست نییە: ': 'الخدمة غير متاحة: ',
  'پشتگیری ناکرێت': 'غير مدعوم',
  'کەمکردنەوە': 'إنقاص',
  'زیادکردن': 'زيادة',
  'شار': 'المدينة',
  'بەکارهێنانی شوێنی ئێستا': 'استخدام موقعي الحالي',
  'داخستن': 'إغلاق',
  'گەڕان بە ناوی کوردی، عەرەبی یان ئینگلیزی':
      'ابحث بالكردية أو العربية أو الإنجليزية',
  'پاککردنەوە': 'مسح',
  'هیچ شارێک نەدۆزرایەوە': 'لم يتم العثور على مدينة',
  'لابردن لە دڵخوازەکان': 'إزالة من المفضلة',
  'زیادکردن بۆ دڵخوازەکان': 'إضافة إلى المفضلة',
  'ڕۆژی پێشوو': 'اليوم السابق',
  'ئەمڕۆ': 'اليوم',
  'ڕۆژی داهاتوو': 'اليوم التالي',
  'خشتەی ئەم ڕۆژە بەردەست نییە؛ تۆمارکردن ناکرێت.':
      'جدول هذا اليوم غير متاح؛ لا يمكن تسجيل الصلاة.',
  'ڕۆژانە': 'اليوم',
  ' تۆمارکراو · ': ' مسجل · ',
  ' نەنووسراو': ' غير مسجل',
  '٧ ڕۆژ': '٧ أيام',
  '٣٠ ڕۆژ': '٣٠ يومًا',
  'ئەنجامدرا': 'أُديت',
  'لەدەستچوو': 'فاتت',
  'تۆمار نەکراوە': 'غير مسجلة',
  'گۆڕینی دۆخ': 'تغيير الحالة',
  'ڕێستکردنی ژمارە': 'إعادة ضبط العدّاد',
  'دڵنیایت دەتەوێت ژمارەکە سفر بکەیتەوە؟':
      'هل تريد بالتأكيد إعادة العدّاد إلى الصفر؟',
  'نەخێر': 'لا',
  'بەڵێ، سفر': 'نعم، صفّر العدّاد',
  'ئامانجی تایبەت': 'هدف مخصص',
  'ژمارە': 'العدد',
  'پاشەکەوت': 'حفظ',
  'تەسبیحی دیجیتاڵ': 'التسبيح الرقمي',
  'ڕێستکردن': 'إعادة الضبط',
  'ئامانج': 'الهدف',
  'تایبەت': 'مخصص',
  'یەک هەنگاو پاشەوە': 'تراجع خطوة واحدة',
  'ژمارەکە لەسەر ئامێرەکەت پاشەکەوت دەکرێت.': 'يُحفظ العدّاد على جهازك.',
  'کانوونی دووەم': 'يناير',
  'شوبات': 'فبراير',
  'ئازار': 'مارس',
  'نیسان': 'أبريل',
  'ئایار': 'مايو',
  'حوزەیران': 'يونيو',
  'تەممووز': 'يوليو',
  'ئاب': 'أغسطس',
  'ئەیلوول': 'سبتمبر',
  'تشرینی یەکەم': 'أكتوبر',
  'تشرینی دووەم': 'نوفمبر',
  'کانوونی یەکەم': 'ديسمبر',
  'ڕۆژژمێری مانگانە': 'التقويم الشهري',
  'مانگی پێشوو': 'الشهر السابق',
  'مانگی داهاتوو': 'الشهر التالي',
  'هەڵاتن': 'الشروق',
  'خەوتن': 'العشاء',
  'بەرواری هیجریی خەمڵێنراوە؛ ڕۆژبژمێری مانگ‌بینینی ناوخۆیی لەوانەیە جیاواز بێت.': 'التاريخ الهجري تقديري؛ وقد يختلف عن التقويم المحلي المعتمد على رؤية الهلال.',
  'GPS لە ئامێرەکەتدا ناچالاکە.': 'خدمة الموقع معطلة على جهازك.',
  'مۆڵەتی شوێن نەدراوە.': 'لم يتم منح إذن الموقع.',
  'مۆڵەتی شوێن لە ڕێکخستنەکانی ئامێرەکەت چالاک بکە.':
      'فعّل إذن الموقع من إعدادات جهازك.',
  'شوێن نەدۆزرایەوە. دووبارە هەوڵ بدە.': 'تعذر تحديد الموقع. حاول مرة أخرى.',
  'نەتوانرا شوێن وەربگیرێت.': 'تعذر الحصول على الموقع.',
  'خزمەتی شوێن لەم پلاتفۆرمەدا بەردەست نییە.':
      'خدمة الموقع غير متاحة على هذه المنصة.',
  'هیچ شاری خشتەدار بۆ ئەم شوێنە بەردەست نییە.':
      'لا توجد مدينة مدعومة بالجداول لهذا الموقع.',
  'هەولێر': 'أربيل',
  'سلێمانی': 'السليمانية',
  'دهۆک': 'دهوك',
  'هەڵەبجە': 'حلبجة',
  'دیالە': 'ديالى',
  'کەرکووک': 'كركوك',
  'نەینەوا': 'نينوى',
  'سەلاحەدین': 'صلاح الدين',
  'خۆڵەکە': 'دقيقة',
  'مۆڵەتی نۆتیفیکەیشن نەدراوە.': 'لم يتم منح إذن الإشعارات.',
};

const _english = <String, String>{
  'سەرەکی': 'Home',
  'ڕۆژژمێر': 'Calendar',
  'زیاتر': 'More',
  'نوێژەکان': 'Prayers',
  'ڕێکخستن': 'Settings',
  'دووشەممە': 'Monday',
  'سێشەممە': 'Tuesday',
  'چوارشەممە': 'Wednesday',
  'پێنجشەممە': 'Thursday',
  'هەینی': 'Friday',
  'شەممە': 'Saturday',
  'یەکشەممە': 'Sunday',
  'هیجری خەمڵێنراو': 'Approximate Hijri date',
  'نوێژی داهاتوو': 'Next prayer',
  'هەڵاتنی خۆر': 'Sunrise',
  'کات بەردەست نییە': 'Prayer time unavailable',
  'دووبارە هەوڵبدەوە': 'Try again',
  'هەژمارکراو': 'Calculated',
  'ئۆفلاین': 'Offline',
  'خشتەی شار': 'City timetable',
  'تەسبیح': 'Tasbih',
  'کاتەکانی نوێژ': 'Prayer times',
  'تۆماری نوێژ': 'Prayer tracker',
  'ڕۆژژمێری هیجری': 'Hijri calendar',
  'ڕووکار': 'Appearance',
  'سیستەم': 'System',
  'ڕووناک': 'Light',
  'تاریک': 'Dark',
  'زمان': 'Language',
  'کوردی': 'Sorani Kurdish',
  'عەرەبی': 'Arabic',
  'شوێن': 'Location',
  'کاتەکان': 'Times',
  'کاتی حیسابکراو': 'Calculated times',
  'بەیانی': 'Fajr',
  'نیوەڕۆ': 'Dhuhr',
  'عەسر': 'Asr',
  'ئێوارە': 'Maghrib',
  'خەوتنان': 'Isha',
  'ڕاستکردنەوەی هیجری': 'Hijri date adjustment',
  'ڕۆژ': 'day',
  'لێدان': 'Vibration',
  'ئاگادارکردنەوەی نوێژ': 'Prayer notifications',
  'لە وێب نۆتیفیکەیشن چالاک نییە': 'Notifications are unavailable on the web',
  'لە ئەپی Android یان iOS بەردەستە': 'Available in the Android or iOS app',
  'مۆڵەتی نۆتیفیکەیشن نەدراوە؛ لە ڕێکخستنەکانی ئامێرەکەت چالاکی بکە.':
      'Notification permission was denied. Enable it in your device settings.',
  'نۆتیفیکەیشن لەم پلاتفۆرمەدا پشتگیری ناکرێت.':
      'Notifications are not supported on this platform.',
  'نۆتیفیکەیشن لەم پلاتفۆرمەدا بەردەست نییە.':
      'Notifications are unavailable on this platform.',
  'ئاگادارکردنەوە پێش کات': 'Reminder before prayer',
  'پێشوەختە': 'In advance',
  'لەرزین': 'Vibration',
  'بێدەنگ': 'Silent',
  'تاقیکردنەوە': 'Test notification',
  'تایبەتمەندی': 'Privacy',
  'داتاکانت تەنها لەسەر ئامێرەکەتە': 'Your data stays on your device',
  'سڕینەوەی داتای کەسی': 'Clear personal data',
  'سەرچاوە': 'Source',
  'خشتەی بانگ | Kurdistan': 'Bang | Kurdistan timetable',
  'داتای لایەنی سێیەم · حکومی نییە':
      'Third-party data · not government-certified',
  'سڕینەوەی داتا': 'Clear data',
  'ژمارە، ڕاستکردنەوە و دڵخوازەکان دەسڕدرێنەوە.':
      'Counts, adjustments, and favorites will be cleared.',
  'پاشگەزبوونەوە': 'Cancel',
  'بسڕەوە': 'Clear',
  'نۆتیفیکەیشنی تاقیکردنەوە نێردرا': 'Test notification sent',
  'نەتوانرا نۆتیفیکەیشن بنێردرێت: ': 'Could not send notification: ',
  'خزمەتگوزاری بەردەست نییە: ': 'Service unavailable: ',
  'پشتگیری ناکرێت': 'Not supported',
  'کەمکردنەوە': 'Decrease',
  'زیادکردن': 'Increase',
  'شار': 'City',
  'بەکارهێنانی شوێنی ئێستا': 'Use current location',
  'داخستن': 'Close',
  'گەڕان بە ناوی کوردی، عەرەبی یان ئینگلیزی':
      'Search by Kurdish, Arabic, or English name',
  'پاککردنەوە': 'Clear',
  'هیچ شارێک نەدۆزرایەوە': 'No cities found',
  'لابردن لە دڵخوازەکان': 'Remove from favorites',
  'زیادکردن بۆ دڵخوازەکان': 'Add to favorites',
  'ڕۆژی پێشوو': 'Previous day',
  'ئەمڕۆ': 'Today',
  'ڕۆژی داهاتوو': 'Next day',
  'خشتەی ئەم ڕۆژە بەردەست نییە؛ تۆمارکردن ناکرێت.':
      'This day’s timetable is unavailable; prayers cannot be recorded.',
  'ڕۆژانە': 'Today',
  ' تۆمارکراو · ': ' recorded · ',
  ' نەنووسراو': ' not recorded',
  '٧ ڕۆژ': '7 days',
  '٣٠ ڕۆژ': '30 days',
  'ئەنجامدرا': 'Prayed',
  'لەدەستچوو': 'Missed',
  'تۆمار نەکراوە': 'Not recorded',
  'گۆڕینی دۆخ': 'Change status',
  'ڕێستکردنی ژمارە': 'Reset counter',
  'دڵنیایت دەتەوێت ژمارەکە سفر بکەیتەوە؟':
      'Are you sure you want to reset the counter?',
  'نەخێر': 'No',
  'بەڵێ، سفر': 'Yes, reset',
  'ئامانجی تایبەت': 'Custom target',
  'ژمارە': 'Number',
  'پاشەکەوت': 'Save',
  'تەسبیحی دیجیتاڵ': 'Digital Tasbih',
  'ڕێستکردن': 'Reset',
  'ئامانج': 'Target',
  'تایبەت': 'Custom',
  'یەک هەنگاو پاشەوە': 'Undo one count',
  'ژمارەکە لەسەر ئامێرەکەت پاشەکەوت دەکرێت.':
      'Your count is saved on this device.',
  'کانوونی دووەم': 'January',
  'شوبات': 'February',
  'ئازار': 'March',
  'نیسان': 'April',
  'ئایار': 'May',
  'حوزەیران': 'June',
  'تەممووز': 'July',
  'ئاب': 'August',
  'ئەیلوول': 'September',
  'تشرینی یەکەم': 'October',
  'تشرینی دووەم': 'November',
  'کانوونی یەکەم': 'December',
  'ڕۆژژمێری مانگانە': 'Monthly calendar',
  'مانگی پێشوو': 'Previous month',
  'مانگی داهاتوو': 'Next month',
  'هەڵاتن': 'Sunrise',
  'خەوتن': 'Isha',
  'بەرواری هیجریی خەمڵێنراوە؛ ڕۆژبژمێری مانگ‌بینینی ناوخۆیی لەوانەیە جیاواز بێت.': 'The Hijri date is approximate and may differ from local moon-sighting calendars.',
  'GPS لە ئامێرەکەتدا ناچالاکە.': 'Location services are turned off.',
  'مۆڵەتی شوێن نەدراوە.': 'Location permission was denied.',
  'مۆڵەتی شوێن لە ڕێکخستنەکانی ئامێرەکەت چالاک بکە.':
      'Enable location permission in your device settings.',
  'شوێن نەدۆزرایەوە. دووبارە هەوڵ بدە.':
      'Could not determine your location. Try again.',
  'نەتوانرا شوێن وەربگیرێت.': 'Could not get your location.',
  'خزمەتی شوێن لەم پلاتفۆرمەدا بەردەست نییە.':
      'Location services are unavailable on this platform.',
  'هیچ شاری خشتەدار بۆ ئەم شوێنە بەردەست نییە.':
      'No city timetable is available for this location.',
  'هەولێر': 'Erbil',
  'سلێمانی': 'Sulaymaniyah',
  'دهۆک': 'Duhok',
  'هەڵەبجە': 'Halabja',
  'دیالە': 'Diyala',
  'کەرکووک': 'Kirkuk',
  'نەینەوا': 'Nineveh',
  'سەلاحەدین': 'Saladin',
  'خۆڵەکە': 'minutes',
  'مۆڵەتی نۆتیفیکەیشن نەدراوە.': 'Notification permission was not granted.',
};

const _weekdays = <AppLanguage, List<String>>{
  AppLanguage.ku: [
    'دووشەممە',
    'سێشەممە',
    'چوارشەممە',
    'پێنجشەممە',
    'هەینی',
    'شەممە',
    'یەکشەممە',
  ],
  AppLanguage.ar: [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ],
  AppLanguage.en: [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ],
};

const _gregorianMonths = <AppLanguage, List<String>>{
  AppLanguage.ku: [
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
  ],
  AppLanguage.ar: [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ],
  AppLanguage.en: [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
};
