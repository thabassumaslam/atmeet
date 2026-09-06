import 'package:atmeet/domain/meeting.dart';
import 'package:atmeet/services/local_answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Meeting', () {
    test('round trips through JSON without losing transcript data', () {
      final meeting = Meeting(
        id: 'meet-1',
        title: 'Design review',
        createdAt: DateTime.utc(2026, 9, 6, 9, 12),
        durationMs: 75000,
        audioPath: '/private/meeting.m4a',
        transcript: const [
          TranscriptSegment(
            speaker: 'Sam',
            text: 'We will ship the new onboarding on Friday.',
            startMs: 12000,
            endMs: 16000,
          ),
        ],
      );

      final restored = Meeting.fromJson(meeting.toJson());

      expect(restored.id, meeting.id);
      expect(restored.createdAt, meeting.createdAt);
      expect(restored.transcript.single.speaker, 'Sam');
      expect(restored.transcript.single.startMs, 12000);
    });
  });

  group('LocalAnswerService', () {
    final meeting = Meeting(
      id: 'meet-2',
      title: 'Planning',
      createdAt: DateTime.utc(2026),
      durationMs: 60000,
      audioPath: null,
      transcript: const [
        TranscriptSegment(
          speaker: 'A',
          text: 'Fatima owns the launch checklist for Friday.',
          startMs: 42000,
          endMs: 47000,
        ),
        TranscriptSegment(
          speaker: 'B',
          text: 'The design review will happen on Tuesday.',
          startMs: 51000,
          endMs: 55000,
        ),
      ],
    );

    test('returns the most relevant timestamped evidence', () {
      final answer = LocalAnswerService().answer(
        'Who owns the launch checklist?',
        meeting,
      );
      expect(answer, contains('Fatima owns'));
      expect(answer, contains('[0:42]'));
      expect(answer, isNot(contains('Tuesday')));
    });

    test('does not invent an answer without evidence', () {
      final answer = LocalAnswerService().answer(
        'What was the budget?',
        meeting,
      );
      expect(answer, contains('could not find evidence'));
    });
  });
}
