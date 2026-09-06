import 'dart:io';

import 'desktop_window_service.dart';

bool isDesktopPlatform() => Platform.isMacOS || Platform.isWindows;

Future<void> preparePlatformWindow() => DesktopWindowService.prepareWindow();
