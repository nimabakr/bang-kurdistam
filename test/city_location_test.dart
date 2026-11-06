import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_bang/services/city_location.dart';

void main() {
  test('nearest city uses only cities with supported timetable files', () {
    final city = CityLocation.nearestCityForCoordinates(
      latitude: 36.1911744,
      longitude: 44.0094145,
    );

    expect(city.id, 'erbil');
    expect(city.timetableFile, isNotNull);
  });

  test('invalid location coordinates are rejected', () {
    expect(
      () => CityLocation.nearestCityForCoordinates(
        latitude: double.nan,
        longitude: 44,
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          CityLocation.nearestCityForCoordinates(latitude: 36, longitude: 181),
      throwsArgumentError,
    );
  });
}
