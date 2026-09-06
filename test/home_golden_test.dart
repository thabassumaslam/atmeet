import 'package:atmeet/app/theme.dart';
import 'package:atmeet/controllers/meeting_controller.dart';
import 'package:atmeet/domain/meeting.dart';
import 'package:atmeet/services/audio_recorder_service.dart';
import 'package:atmeet/services/audio_playback_service.dart';
import 'package:atmeet/services/meeting_repository.dart';
import 'package:atmeet/services/offline_transcriber.dart';
import 'package:atmeet/ui/meet_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop popup matches the focused recorder layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MeetingController(
      _MemoryRepository(),
      _FakeRecorder(),
      _FakePlayer(),
      _FakeTranscriber(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AtMeetTheme.dark,
        home: MeetHome(controller: controller, isDesktop: true),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MeetHome),
      matchesGoldenFile('goldens/home.png'),
    );
  });
}

class _MemoryRepository implements MeetingRepository {
  @override
  Future<List<Meeting>> load() async => [];
  @override
  Future<void> save(List<Meeting> meetings) async {}
  @override
  Future<String> createRecordingPath(String id, DateTime createdAt) async =>
      'test.m4a';
  @override
  Future<void> finishRecording(String path) async {}
  @override
  Future<int> recoverRecordingMarkers() async => 0;
}

class _FakeRecorder implements AudioRecorderService {
  @override
  Future<double> amplitude() async => 0.3;
  @override
  Future<void> dispose() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> start(String path) async {}
  @override
  Future<String?> stop() async => null;
}

class _FakePlayer implements AudioPlaybackService {
  @override
  Stream<bool> get playingChanges => const Stream.empty();
  @override
  Future<void> dispose() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play(String path) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
}

class _FakeTranscriber implements OfflineTranscriber {
  @override
  Future<void> downloadModel(void Function(double progress) onProgress) async {}
  @override
  Future<bool> isModelReady() async => false;
  @override
  Future<List<TranscriptSegment>> transcribe(String audioPath) async => [];
}
