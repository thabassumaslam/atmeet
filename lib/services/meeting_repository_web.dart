import 'dart:async';

import '../domain/meeting.dart';

abstract interface class MeetingRepository {
  Future<List<Meeting>> load();
  Future<void> save(List<Meeting> meetings);
  Future<String> createRecordingPath(String id, DateTime createdAt);
  Future<void> finishRecording(String path);
  Future<int> recoverRecordingMarkers();
}

class LocalMeetingRepository implements MeetingRepository {
  static List<Meeting> _meetings = [];

  @override
  Future<List<Meeting>> load() async => List.of(_meetings);

  @override
  Future<void> save(List<Meeting> meetings) async {
    _meetings = List.of(meetings);
  }

  @override
  Future<String> createRecordingPath(String id, DateTime createdAt) async =>
      'atmeet-$id.m4a';

  @override
  Future<void> finishRecording(String path) async {}

  @override
  Future<int> recoverRecordingMarkers() async => 0;
}
