import 'package:audioplayers/audioplayers.dart';

abstract interface class AudioPlaybackService {
  Stream<bool> get playingChanges;
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class DeviceAudioPlayback implements AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<bool> get playingChanges =>
      _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}
