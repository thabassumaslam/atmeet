import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app/atmeet_app.dart';
import 'services/desktop_window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDesktop = Platform.isMacOS || Platform.isWindows;
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await DesktopWindowService.prepareWindow();
  }
  runApp(AtMeetApp(isDesktop: isDesktop));
}
