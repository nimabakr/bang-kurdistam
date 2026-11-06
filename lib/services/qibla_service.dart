import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import '../domain/city.dart';

class QiblaService {
  static const kaabaLatitude = 21.4225241;
  static const kaabaLongitude = 39.8261818;

  static double bearingFrom(City city) {
    final latitude = city.latitude;
    final longitude = city.longitude;
    if (latitude == null || longitude == null) {
      throw ArgumentError(
        'Coordinates are unavailable for ${city.englishName}.',
      );
    }
    final latitudeRadians = _radians(latitude);
    final kaabaLatitudeRadians = _radians(kaabaLatitude);
    final deltaLongitude = _radians(kaabaLongitude - longitude);

    final y = math.sin(deltaLongitude);
    final x =
        math.cos(latitudeRadians) * math.tan(kaabaLatitudeRadians) -
        math.sin(latitudeRadians) * math.cos(deltaLongitude);

    return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  static double relativeBearing({
    required double qiblaBearing,
    required double heading,
  }) {
    return normalizeDegrees(qiblaBearing - heading);
  }

  static double? headingFromMagnetometer(MagnetometerEvent event) {
    if (_isZeroVector(event.x, event.y, event.z)) return null;
    final heading = math.atan2(event.y, event.x) * 180 / math.pi;
    return normalizeDegrees(heading);
  }

  static double normalizeDegrees(double degrees) => (degrees % 360 + 360) % 360;

  static bool _isZeroVector(double x, double y, double z) =>
      x.abs() < 1e-9 && y.abs() < 1e-9 && z.abs() < 1e-9;

  static double _radians(double degrees) => degrees * math.pi / 180;
}
