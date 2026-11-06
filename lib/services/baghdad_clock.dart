import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void initializeBangTimeZones() {
  tzdata.initializeTimeZones();
}

tz.Location get baghdadLocation => tz.getLocation('Asia/Baghdad');

tz.TZDateTime baghdadNow() => tz.TZDateTime.now(baghdadLocation);

tz.TZDateTime baghdadDate(DateTime date) =>
    tz.TZDateTime(baghdadLocation, date.year, date.month, date.day);
