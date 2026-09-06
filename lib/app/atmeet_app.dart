import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../controllers/meeting_controller.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_playback_service.dart';
import '../services/meeting_repository.dart';
import '../services/offline_transcriber.dart';
import '../ui/meet_home.dart';
import 'theme.dart';

class AtMeetApp extends StatefulWidget {
  const AtMeetApp({super.key, required this.isDesktop});
  final bool isDesktop;

  @override
  State<AtMeetApp> createState() => _AtMeetAppState();
}

class _AtMeetAppState extends State<AtMeetApp> {
  late final MeetingController controller;

  @override
  void initState() {
    super.initState();
    controller = MeetingController(
      LocalMeetingRepository(),
      DeviceAudioRecorder(),
      DeviceAudioPlayback(),
      SherpaOfflineTranscriber(),
    );
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '@meet',
      debugShowCheckedModeBanner: false,
      theme: AtMeetTheme.dark,
      scrollBehavior: const CupertinoScrollBehavior(),
      home: MeetHome(controller: controller, isDesktop: widget.isDesktop),
    );
  }
}
