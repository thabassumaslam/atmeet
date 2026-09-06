import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/meeting.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_playback_service.dart';
import '../services/local_answer_service.dart';
import '../services/meeting_repository.dart';
import '../services/offline_transcriber.dart';

enum CaptureState { idle, recording, paused, transcribing }

class MeetingController extends ChangeNotifier {
  MeetingController(
    this._repository,
    this._recorder,
    this._player,
    this._transcriber,
  ) {
    _playbackSubscription = _player.playingChanges.listen((playing) {
      isPlaying = playing;
      notifyListeners();
    });
  }

  final MeetingRepository _repository;
  final AudioRecorderService _recorder;
  final AudioPlaybackService _player;
  final OfflineTranscriber _transcriber;
  final LocalAnswerService _answerService = LocalAnswerService();
  final Stopwatch _stopwatch = Stopwatch();

  final List<Meeting> meetings = [];
  final List<ChatMessage> messages = [];
  CaptureState captureState = CaptureState.idle;
  Meeting? selectedMeeting;
  Duration elapsed = Duration.zero;
  double amplitude = 0.05;
  String? errorMessage;
  bool initialized = false;
  bool modelReady = false;
  double modelProgress = 0;
  Timer? _pulse;
  StreamSubscription<bool>? _playbackSubscription;
  bool isPlaying = false;
  bool _playbackPaused = false;

  bool get isRecording => captureState == CaptureState.recording;
  bool get isPaused => captureState == CaptureState.paused;
  bool get isBusy => captureState == CaptureState.transcribing;
  bool get hasActivePlayback => isPlaying || _playbackPaused;

  Future<void> initialize() async {
    final recoveredRecordings = await _repository.recoverRecordingMarkers();
    meetings
      ..clear()
      ..addAll(await _repository.load());
    if (meetings.isNotEmpty) selectedMeeting = meetings.first;
    modelReady = await _transcriber.isModelReady();
    messages.add(
      ChatMessage(
        role: ChatRole.assistant,
        text: recoveredRecordings > 0
            ? 'I recovered $recoveredRecordings interrupted recording${recoveredRecordings == 1 ? '' : 's'} from the previous session.'
            : meetings.isEmpty
            ? 'Ready when you are. Record a meeting, and everything stays on this device.'
            : 'Welcome back. Ask anything about ${selectedMeeting!.title}.',
        time: DateTime.now(),
      ),
    );
    initialized = true;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (captureState != CaptureState.idle) return;
    errorMessage = null;
    try {
      if (isPlaying || _playbackPaused) await stopPlayback();
      if (!await _recorder.hasPermission()) {
        errorMessage = 'Microphone permission is required to record.';
        notifyListeners();
        return;
      }
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();
      final path = await _repository.createRecordingPath(id, now);
      final meeting = Meeting(
        id: id,
        title: 'Meet ${meetings.length + 1}',
        createdAt: now,
        durationMs: 0,
        audioPath: path,
        transcript: const [],
      );
      meetings.insert(0, meeting);
      selectedMeeting = meeting;
      await _repository.save(meetings);
      await _recorder.start(path);
      _stopwatch
        ..reset()
        ..start();
      elapsed = Duration.zero;
      captureState = CaptureState.recording;
      messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Recording started. Audio is saved locally at 24 kHz mono / 64 kbps.',
          time: DateTime.now(),
        ),
      );
      _pulse = Timer.periodic(
        const Duration(milliseconds: 160),
        (_) => _tick(),
      );
    } catch (error) {
      errorMessage = 'Could not start recording: $error';
      captureState = CaptureState.idle;
    }
    notifyListeners();
  }

  Future<void> togglePause() async {
    if (isRecording) {
      await _recorder.pause();
      _stopwatch.stop();
      captureState = CaptureState.paused;
    } else if (isPaused) {
      await _recorder.resume();
      _stopwatch.start();
      captureState = CaptureState.recording;
    }
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    final path = selectedMeeting?.audioPath;
    if (path == null || isRecording || isPaused || isBusy) return;
    try {
      if (isPlaying) {
        await _player.pause();
        _playbackPaused = true;
      } else if (_playbackPaused) {
        await _player.resume();
        _playbackPaused = false;
      } else {
        await _player.play(path);
      }
    } catch (error) {
      errorMessage = 'Could not play recording: $error';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() {
    _playbackPaused = false;
    return _player.stop();
  }

  Future<void> stopRecording() async {
    if (!isRecording && !isPaused) return;
    _pulse?.cancel();
    _stopwatch.stop();
    final path = await _recorder.stop();
    final active = selectedMeeting;
    if (active == null) return;
    final recordedPath = path ?? active.audioPath;
    if (recordedPath != null) await _repository.finishRecording(recordedPath);
    final completed = active.copyWith(
      durationMs: _stopwatch.elapsedMilliseconds,
      audioPath: path ?? active.audioPath,
    );
    _replaceMeeting(completed);
    await _repository.save(meetings);

    if (modelReady && completed.audioPath != null) {
      captureState = CaptureState.transcribing;
      notifyListeners();
      try {
        final transcript = await _transcriber.transcribe(completed.audioPath!);
        final transcribed = completed.copyWith(transcript: transcript);
        _replaceMeeting(transcribed);
        await _repository.save(meetings);
        messages.add(
          ChatMessage(
            role: ChatRole.assistant,
            text: transcript.isEmpty
                ? 'Recording saved. I did not detect clear speech.'
                : 'Recording saved and transcribed locally. Ask me about any decision, topic, or action.',
            time: DateTime.now(),
          ),
        );
      } catch (error) {
        errorMessage = 'Recording saved, but transcription failed: $error';
      }
    } else {
      messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Recording saved locally. Install the offline speech model in Settings to transcribe it.',
          time: DateTime.now(),
        ),
      );
    }
    captureState = CaptureState.idle;
    notifyListeners();
  }

  Future<void> downloadModel() async {
    if (modelReady || modelProgress > 0) return;
    errorMessage = null;
    modelProgress = 0.001;
    notifyListeners();
    try {
      await _transcriber.downloadModel((progress) {
        modelProgress = progress;
        notifyListeners();
      });
      modelReady = true;
      modelProgress = 1;
    } catch (error) {
      modelProgress = 0;
      errorMessage = 'Model installation failed: $error';
    }
    notifyListeners();
  }

  Future<void> transcribeSelected() async {
    final meeting = selectedMeeting;
    if (!modelReady || meeting?.audioPath == null || isBusy) return;
    captureState = CaptureState.transcribing;
    notifyListeners();
    try {
      final transcript = await _transcriber.transcribe(meeting!.audioPath!);
      _replaceMeeting(meeting.copyWith(transcript: transcript));
      await _repository.save(meetings);
    } catch (error) {
      errorMessage = 'Transcription failed: $error';
    }
    captureState = CaptureState.idle;
    notifyListeners();
  }

  void ask(String text) {
    final question = text.trim();
    if (question.isEmpty) return;
    messages.add(
      ChatMessage(role: ChatRole.person, text: question, time: DateTime.now()),
    );
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      messages.add(
        ChatMessage(
          role: ChatRole.assistant,
          text: _answerService.answer(question, selectedMeeting),
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    });
  }

  void select(Meeting meeting) {
    if (isPlaying || _playbackPaused) unawaited(stopPlayback());
    selectedMeeting = meeting;
    messages
      ..clear()
      ..add(
        ChatMessage(
          role: ChatRole.assistant,
          text: meeting.transcript.isEmpty
              ? '${meeting.title} is ready. Transcribe it to ask grounded questions.'
              : 'What would you like to know about ${meeting.title}?',
          time: DateTime.now(),
        ),
      );
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _tick() async {
    elapsed = _stopwatch.elapsed;
    if (isRecording) {
      try {
        amplitude = await _recorder.amplitude();
      } catch (_) {
        amplitude = 0.05;
      }
    }
    notifyListeners();
  }

  void _replaceMeeting(Meeting meeting) {
    final index = meetings.indexWhere((item) => item.id == meeting.id);
    if (index >= 0) meetings[index] = meeting;
    selectedMeeting = meeting;
  }

  @override
  void dispose() {
    _pulse?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_playbackSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
