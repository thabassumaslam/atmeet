import '../domain/meeting.dart';

class LocalAnswerService {
  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'and',
    'are',
    'can',
    'did',
    'for',
    'from',
    'have',
    'how',
    'into',
    'our',
    'that',
    'the',
    'their',
    'them',
    'this',
    'was',
    'what',
    'when',
    'where',
    'which',
    'who',
    'with',
    'would',
  };

  String answer(String question, Meeting? meeting) {
    if (meeting == null) {
      return 'Start or open a recording first. I answer only from your local meeting transcript.';
    }
    if (meeting.transcript.isEmpty) {
      return 'This recording has no transcript yet. Install an offline speech model in Settings, then transcribe it on this device.';
    }
    final query = _tokens(question)
        .where((word) => !_stopWords.contains(word))
        .toSet();
    final ranked =
        meeting.transcript
            .map((segment) {
              final words = _tokens(segment.text).toSet();
              return (
                segment: segment,
                score: query.where(words.contains).length,
              );
            })
            .where((item) => item.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    if (ranked.isEmpty) {
      return 'I could not find evidence for that in this meeting. Try a person, topic, decision, or action mentioned in the transcript.';
    }
    return ranked
        .take(3)
        .map((item) {
          final timestamp = _timestamp(item.segment.startMs);
          return '${item.segment.text.trim()} [$timestamp]';
        })
        .join(' ');
  }

  Iterable<String> _tokens(String value) sync* {
    for (final token in value.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (token.length > 2) yield token;
    }
  }

  String _timestamp(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
