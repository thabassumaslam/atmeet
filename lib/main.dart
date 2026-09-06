import 'package:flutter/widgets.dart';

import 'app/atmeet_app.dart';
import 'services/platform_shell.dart';
import 'services/window_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDesktop = isDesktopPlatform();
  if (isDesktop) {
    await ensureWindowManager();
    await preparePlatformWindow();
  }
  runApp(AtMeetApp(isDesktop: isDesktop));
}
