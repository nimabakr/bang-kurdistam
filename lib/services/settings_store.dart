import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsStore {
  Future<String?> getString(String key);
  Future<int?> getInt(String key);
  Future<List<String>?> getStringList(String key);
  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore() : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<int?> getInt(String key) => _preferences.getInt(key);

  @override
  Future<List<String>?> getStringList(String key) =>
      _preferences.getStringList(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> setInt(String key, int value) => _preferences.setInt(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _preferences.setStringList(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
