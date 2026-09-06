import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/meeting.dart';

abstract interface class MeetingRepository {
  Future<List<Meeting>> load();
  Future<void> save(List<Meeting> meetings);
  Future<String> createRecordingPath(String id, DateTime createdAt);
  Future<void> finishRecording(String path);
  Future<int> recoverRecordingMarkers();
}

class LocalMeetingRepository implements MeetingRepository {
  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}${Platform.pathSeparator}atmeet');
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> recordingsDirectory() async {
    final root = await _root();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}recordings',
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String> createRecordingPath(String id, DateTime createdAt) async {
    final root = await recordingsDirectory();
    final folder = '${createdAt.toIso8601String().replaceAll(':', '-')}_$id';
    final session = Directory('${root.path}${Platform.pathSeparator}$folder');
    await session.create(recursive: true);
    final marker = File('${session.path}${Platform.pathSeparator}.recording');
    await marker.writeAsString(createdAt.toIso8601String(), flush: true);
    return '${session.path}${Platform.pathSeparator}meeting.m4a';
  }

  @override
  Future<void> finishRecording(String path) async {
    final marker = File(
      '${File(path).parent.path}${Platform.pathSeparator}.recording',
    );
    if (await marker.exists()) await marker.delete();
  }

  @override
  Future<List<Meeting>> load() async {
    final root = await _root();
    final file = File('${root.path}${Platform.pathSeparator}meetings.json');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    if (!await file.exists()) {
      if (await temporary.exists()) {
        await temporary.rename(file.path);
      } else if (await backup.exists()) {
        await backup.rename(file.path);
      }
    }
    if (!await file.exists()) return [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return decoded
          .map((item) => Meeting.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    }
  }

  @override
  Future<void> save(List<Meeting> meetings) async {
    final root = await _root();
    final file = File('${root.path}${Platform.pathSeparator}meetings.json');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(meetings.map((meeting) => meeting.toJson()).toList());
    await temporary.writeAsString(encoded, flush: true);
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  @override
  Future<int> recoverRecordingMarkers() async {
    final root = await recordingsDirectory();
    var recovered = 0;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final marker = File('${entity.path}${Platform.pathSeparator}.recording');
      if (!await marker.exists()) continue;
      final audio = File('${entity.path}${Platform.pathSeparator}meeting.m4a');
      if (await audio.exists() && await audio.length() > 0) recovered++;
      await marker.delete();
    }
    return recovered;
  }
}
