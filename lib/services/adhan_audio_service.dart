import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'settings_store.dart';

class AdhanAudioService {
  AdhanAudioService({SettingsStore? settingsStore})
    : _settingsStore = settingsStore ?? SharedPreferencesSettingsStore();

  static const assetPath = 'audio/adhan_tone.wav';

  final SettingsStore _settingsStore;
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isInitialized = false;

  bool get isPlaying => _isPlaying;

  Future<void> initialize() async {
    _isInitialized = true;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(1.0);
  }

  Future<void> playPreview() async {
    if (!_isInitialized) await initialize();
    await _player.stop();
    await _player.play(AssetSource(assetPath));
    _isPlaying = true;
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (!_isInitialized) return;
    await _player.resume();
    _isPlaying = true;
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _player.stop();
    _isPlaying = false;
  }

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration?> get onDurationChanged => _player.onDurationChanged;

  Future<Duration?> getDuration() => _player.getDuration();
  Future<Duration?> getCurrentPosition() => _player.getCurrentPosition();

  Future<bool> isEnabled() async {
    final value = await _settingsStore.getInt('adhan_audio_enabled');
    return value != 0;
  }

  Future<void> setEnabled(bool enabled) async {
    await _settingsStore.setInt('adhan_audio_enabled', enabled ? 1 : 0);
    if (!enabled) await stop();
  }

  Future<String> selectedPreset() async {
    final value = await _settingsStore.getString('adhan_audio_preset');
    return switch (value) {
      'tone' => 'tone',
      _ => 'tone',
    };
  }

  Future<void> setPreset(String value) async {
    if (value != 'tone') throw ArgumentError.value(value, 'value');
    await _settingsStore.setString('adhan_audio_preset', value);
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
