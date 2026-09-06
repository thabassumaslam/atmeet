class TranscriptSegment {
  const TranscriptSegment({
    required this.speaker,
    required this.text,
    required this.startMs,
    required this.endMs,
  });
  final String speaker;
  final String text;
  final int startMs;
  final int endMs;

  Map<String, Object> toJson() => {
    'speaker': speaker,
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      speaker: json['speaker'] as String? ?? 'Speaker',
      text: json['text'] as String? ?? '',
      startMs: json['startMs'] as int? ?? 0,
      endMs: json['endMs'] as int? ?? 0,
    );
  }
}

class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationMs,
    required this.audioPath,
    required this.transcript,
  });
  final String id;
  final String title;
  final DateTime createdAt;
  final int durationMs;
  final String? audioPath;
  final List<TranscriptSegment> transcript;

  Meeting copyWith({
    String? title,
    int? durationMs,
    String? audioPath,
    List<TranscriptSegment>? transcript,
  }) => Meeting(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    durationMs: durationMs ?? this.durationMs,
    audioPath: audioPath ?? this.audioPath,
    transcript: transcript ?? this.transcript,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'durationMs': durationMs,
    'audioPath': audioPath,
    'transcript': transcript.map((segment) => segment.toJson()).toList(),
  };

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Untitled meeting',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    durationMs: json['durationMs'] as int? ?? 0,
    audioPath: json['audioPath'] as String?,
    transcript: (json['transcript'] as List<dynamic>? ?? const [])
        .map((item) => TranscriptSegment.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

enum ChatRole { person, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.time,
  });
  final ChatRole role;
  final String text;
  final DateTime time;
}
