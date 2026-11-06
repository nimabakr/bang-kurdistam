import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_bang/app_state.dart';
import 'package:kurdistan_bang/domain/city.dart';
import 'package:kurdistan_bang/main.dart';
import 'package:kurdistan_bang/services/baghdad_clock.dart';
import 'package:kurdistan_bang/services/qibla_service.dart';
import 'package:kurdistan_bang/services/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeBangTimeZones();
  test('city search includes Kalar by all supported names', () {
    final kalar = cities.firstWhere((city) => city.id == 'kalar');

    expect(kalar.matches('Kalar'), isTrue);
    expect(kalar.matches('کەلار'), isTrue);
    expect(kalar.matches('كلار'), isTrue);
    expect(cities.where((city) => city.matches('Penjwen')).length, 1);
  });

  test('qibla bearing is normalized and points southeast from Kurdistan', () {
    final bearing = QiblaService.bearingFrom(
      cities.firstWhere((city) => city.id == 'erbil'),
    );

    expect(bearing, inInclusiveRange(0, 360));
    expect(bearing, inInclusiveRange(150, 260));
  });

  test('bearing and relative heading stay in range for edge cases', () {
    final city = cities.firstWhere((city) => city.id == 'kalar');
    final bearing = QiblaService.bearingFrom(city);
    expect(bearing, inInclusiveRange(0, 360));
    expect(
      QiblaService.relativeBearing(qiblaBearing: bearing, heading: 0),
      inInclusiveRange(0, 360),
    );
    expect(
      QiblaService.relativeBearing(qiblaBearing: 10, heading: 350),
      closeTo(20, 1e-6),
    );
    expect(QiblaService.normalizeDegrees(-10), closeTo(350, 1e-6));
  });

  test('city records include coordinate references and Baghdad timezone', () {
    for (final city in cities) {
      expect(city.coordinateReference, isNotEmpty);
      expect(city.timezone, 'Asia/Baghdad');
    }
  });

  testWidgets('Sorani Qibla label uses the correct spelling', (tester) async {
    final state = BangAppState(_MemorySettingsStore());
    state.scheduleLoading = true;
    await tester.pumpWidget(BangApp(state: state));

    expect(find.text('قیبلە'), findsOneWidget);
    expect(find.text('قەبلە'), findsNothing);
  });
}

class _MemorySettingsStore implements SettingsStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<List<String>?> getStringList(String key) async => null;

  @override
  Future<void> setString(String key, String value) async {}

  @override
  Future<void> setInt(String key, int value) async {}

  @override
  Future<void> setStringList(String key, List<String> value) async {}

  @override
  Future<void> remove(String key) async {}
}
