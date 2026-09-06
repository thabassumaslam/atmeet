import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../domain/meeting.dart';

abstract interface class OfflineTranscriber {
  Future<bool> isModelReady();
  Future<void> downloadModel(void Function(double progress) onProgress);
  Future<List<TranscriptSegment>> transcribe(String audioPath);
}

class SherpaOfflineTranscriber implements OfflineTranscriber {
  static const modelName = 'sherpa-onnx-whisper-tiny.en';
  static const modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      '$modelName.tar.bz2';

  Future<Directory> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}atmeet'
      '${Platform.pathSeparator}models${Platform.pathSeparator}$modelName',
    );
  }

  @override
  Future<bool> isModelReady() async {
    final directory = await _modelDirectory();
    return File('${directory.path}/encoder.int8.onnx').existsSync() &&
        File('${directory.path}/decoder.int8.onnx').existsSync() &&
        File('${directory.path}/tokens.txt').existsSync();
  }

  @override
  Future<void> downloadModel(void Function(double progress) onProgress) async {
    final directory = await _modelDirectory();
    final modelsRoot = directory.parent;
    await modelsRoot.create(recursive: true);
    final archiveFile = File('${modelsRoot.path}/$modelName.tar.bz2.part');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(modelUrl));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Model download failed (${response.statusCode})');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = archiveFile.openWrite();
      try {
        await for (final bytes in response) {
          sink.add(bytes);
          received += bytes.length;
          if (total > 0) onProgress(received / total * 0.82);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
    onProgress(0.84);

    await Isolate.run(() => _extractModel(archiveFile.path, modelsRoot.path));
    await archiveFile.delete();
    if (!await isModelReady()) {
      throw const FileSystemException('Downloaded model is incomplete');
    }
    onProgress(1);
  }

  static void _extractModel(String archivePath, String destination) {
    final compressed = File(archivePath).readAsBytesSync();
    final tarBytes = BZip2Decoder().decodeBytes(compressed);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final entry in archive) {
      final safeName = entry.name.replaceAll('\\', '/');
      if (safeName.contains('../') || safeName.startsWith('/')) continue;
      final output = '$destination${Platform.pathSeparator}$safeName';
      if (entry.isFile) {
        final file = File(output)..parent.createSync(recursive: true);
        file.writeAsBytesSync(entry.content as List<int>, flush: true);
      } else {
        Directory(output).createSync(recursive: true);
      }
    }
  }

  @override
  Future<List<TranscriptSegment>> transcribe(String audioPath) async {
    if (!await isModelReady()) {
      throw StateError('Offline speech model is not installed');
    }
    final wavPath = '$audioPath.asr.wav';
    final command =
        '-y -i ${_quote(audioPath)} -vn -ac 1 -ar 16000 -c:a pcm_s16le '
        '${_quote(wavPath)}';
    final conversion = await FFmpegKit.execute(command);
    final returnCode = await conversion.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      throw StateError('Could not prepare the recording for transcription');
    }

    try {
      final directory = await _modelDirectory();
      return await Isolate.run(() {
        sherpa.initBindings();
        final config = sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: '${directory.path}/encoder.int8.onnx',
              decoder: '${directory.path}/decoder.int8.onnx',
              language: 'en',
              task: 'transcribe',
              enableTokenTimestamps: true,
              enableSegmentTimestamps: true,
            ),
            tokens: '${directory.path}/tokens.txt',
            numThreads: Platform.numberOfProcessors.clamp(1, 4),
            debug: false,
            modelType: 'whisper',
          ),
        );
        final recognizer = sherpa.OfflineRecognizer(config);
        final wave = sherpa.readWave(wavPath);
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(
            samples: wave.samples,
            sampleRate: wave.sampleRate,
          );
          recognizer.decode(stream);
          final result = recognizer.getResult(stream);
          final endMs = wave.sampleRate == 0
              ? 0
              : (wave.samples.length / wave.sampleRate * 1000).round();
          final text = result.text.trim();
          if (text.isEmpty) return <TranscriptSegment>[];
          return _segmentsFromRecognition(
            text,
            result.tokens,
            result.timestamps,
            endMs,
          );
        } finally {
          stream.free();
          recognizer.free();
        }
      });
    } finally {
      final wav = File(wavPath);
      if (await wav.exists()) await wav.delete();
    }
  }

  String _quote(String value) => '"${value.replaceAll('"', '\\"')}"';
}

List<TranscriptSegment> _segmentsFromRecognition(
  String text,
  List<String> tokens,
  List<double> timestamps,
  int durationMs,
) {
  if (tokens.isNotEmpty && timestamps.length == tokens.length) {
    final segments = <TranscriptSegment>[];
    final buffer = StringBuffer();
    var startMs = (timestamps.first * 1000).round().clamp(0, durationMs);
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token.startsWith('<|') && token.endsWith('|>')) continue;
      buffer.write(token.replaceAll('▁', ' '));
      final closesSentence = RegExp(r'[.!?]\s*$').hasMatch(token);
      if (!closesSentence && buffer.length < 280) continue;
      final endMs = (timestamps[index] * 1000 + 500).round().clamp(
        startMs,
        durationMs,
      );
      final segmentText = buffer.toString().trim();
      if (segmentText.isNotEmpty) {
        segments.add(
          TranscriptSegment(
            speaker: 'Speaker 1',
            text: segmentText,
            startMs: startMs,
            endMs: endMs,
          ),
        );
      }
      buffer.clear();
      if (index + 1 < timestamps.length) {
        startMs = (timestamps[index + 1] * 1000).round().clamp(0, durationMs);
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      segments.add(
        TranscriptSegment(
          speaker: 'Speaker 1',
          text: tail,
          startMs: startMs,
          endMs: durationMs,
        ),
      );
    }
    if (segments.isNotEmpty) return segments;
  }

  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((sentence) => sentence.trim())
      .where((sentence) => sentence.isNotEmpty)
      .toList();
  if (sentences.isEmpty) return [];
  final characterCount = sentences.fold<int>(
    0,
    (total, sentence) => total + sentence.length,
  );
  var consumed = 0;
  return sentences.map((sentence) {
    final start = characterCount == 0
        ? 0
        : (consumed / characterCount * durationMs).round();
    consumed += sentence.length;
    final end = characterCount == 0
        ? durationMs
        : (consumed / characterCount * durationMs).round();
    return TranscriptSegment(
      speaker: 'Speaker 1',
      text: sentence,
      startMs: start,
      endMs: end,
    );
  }).toList();
}
