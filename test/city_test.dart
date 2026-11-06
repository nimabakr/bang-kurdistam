import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_bang/domain/city.dart';

void main() {
  test('city search includes Kalar by all supported names', () {
    final kalar = cities.firstWhere((city) => city.id == 'kalar');

    expect(kalar.matches('Kalar'), isTrue);
    expect(kalar.matches('کەلار'), isTrue);
    expect(kalar.matches('كلار'), isTrue);
    expect(cities.where((city) => city.matches('Penjwen')).length, 1);
  });

  test('city records include coordinate references and Baghdad timezone', () {
    for (final city in cities) {
      expect(city.coordinateReference, isNotEmpty);
      expect(city.timezone, 'Asia/Baghdad');
    }
  });
}
