import 'package:record/record.dart';

abstract interface class AudioRecorderService {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<double> amplitude();
  Future<void> dispose();
}

class DeviceAudioRecorder implements AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 24000,
      bitRate: 64000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
    ),
    path: path,
  );

  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();
  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<double> amplitude() async {
    final value = await _recorder.getAmplitude();
    return ((value.current + 60) / 60).clamp(0.03, 1.0);
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
