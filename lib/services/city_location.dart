import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

import '../domain/city.dart';

class CityLocationException implements Exception {
  const CityLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CityLocation {
  static const _invalidTimetableCityIds = {'arbat', 'qasre', 'tuzxurmatu'};

  static Future<City> nearestTimetabledCity() async {
    late final Position position;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const CityLocationException('GPS لە ئامێرەکەتدا ناچالاکە.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const CityLocationException('مۆڵەتی شوێن نەدراوە.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const CityLocationException(
          'مۆڵەتی شوێن لە ڕێکخستنەکانی ئامێرەکەت چالاک بکە.',
        );
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on CityLocationException {
      rethrow;
    } on LocationServiceDisabledException {
      throw const CityLocationException('GPS لە ئامێرەکەتدا ناچالاکە.');
    } on PermissionDeniedException {
      throw const CityLocationException('مۆڵەتی شوێن نەدراوە.');
    } on TimeoutException {
      throw const CityLocationException('شوێن نەدۆزرایەوە. دووبارە هەوڵ بدە.');
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION_DENIED') {
        throw const CityLocationException('مۆڵەتی شوێن نەدراوە.');
      }
      throw const CityLocationException('نەتوانرا شوێن وەربگیرێت.');
    } on MissingPluginException {
      throw const CityLocationException(
        'خزمەتی شوێن لەم پلاتفۆرمەدا بەردەست نییە.',
      );
    } on UnsupportedError {
      throw const CityLocationException(
        'خزمەتی شوێن لەم پلاتفۆرمەدا بەردەست نییە.',
      );
    }

    return nearestCityForCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static City nearestCityForCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Coordinates are outside valid ranges.');
    }

    final candidates = cities.where(
      (city) =>
          city.latitude != null &&
          city.longitude != null &&
          city.timetableFile != null &&
          !_invalidTimetableCityIds.contains(city.id),
    );
    final ranked = candidates.toList()
      ..sort(
        (a, b) => _distance(
          latitude,
          longitude,
          a,
        ).compareTo(_distance(latitude, longitude, b)),
      );
    if (ranked.isEmpty) {
      throw const CityLocationException(
        'هیچ شاری خشتەدار بۆ ئەم شوێنە بەردەست نییە.',
      );
    }
    return ranked.first;
  }

  static double _distance(double latitude, double longitude, City city) {
    const radiusKm = 6371.0;
    final latitudeDelta = _radians(city.latitude! - latitude);
    final longitudeDelta = _radians(city.longitude! - longitude);
    final startLatitude = _radians(latitude);
    final endLatitude = _radians(city.latitude!);
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(startLatitude) *
            math.cos(endLatitude) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return radiusKm * 2 * math.asin(math.sqrt(haversine.clamp(0, 1)));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
