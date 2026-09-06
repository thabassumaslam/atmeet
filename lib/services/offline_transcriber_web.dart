import '../domain/meeting.dart';

abstract interface class OfflineTranscriber {
  Future<bool> isModelReady();
  Future<void> downloadModel(void Function(double progress) onProgress);
  Future<List<TranscriptSegment>> transcribe(String audioPath);
}

class SherpaOfflineTranscriber implements OfflineTranscriber {
  @override
  Future<bool> isModelReady() async => false;

  @override
  Future<void> downloadModel(void Function(double progress) onProgress) {
    throw UnsupportedError(
      'Download the native offline model on macOS, Windows, Android, or iOS.',
    );
  }

  @override
  Future<List<TranscriptSegment>> transcribe(String audioPath) {
    throw UnsupportedError('Offline ASR is a native target feature.');
  }
}
