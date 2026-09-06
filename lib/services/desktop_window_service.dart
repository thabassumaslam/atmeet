import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowService with TrayListener, WindowListener {
  DesktopWindowService._();
  static final instance = DesktopWindowService._();
  static const windowSize = Size(430, 780);

  static Future<void> prepareWindow() async {
    const options = WindowOptions(
      size: windowSize,
      minimumSize: windowSize,
      maximumSize: windowSize,
      center: true,
      alwaysOnTop: true,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(instance);
    trayManager.addListener(instance);
    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/tray/tray_icon.ico'
            : 'assets/tray/tray_icon.png',
        isTemplate: Platform.isMacOS,
      );
      await trayManager.setToolTip('@meet — private meeting recorder');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'show', label: 'Show @meet'),
            MenuItem.separator(),
            MenuItem(key: 'quit', label: 'Quit @meet'),
          ],
        ),
      );
    } catch (_) {
      // The main window remains usable if a desktop shell cannot load an icon.
    }
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
      return;
    }
    final bounds = await trayManager.getBounds();
    if (bounds != null) {
      await windowManager.setPosition(
        Offset(bounds.right - windowSize.width, bounds.bottom + 8),
      );
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'quit') {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } else if (menuItem.key == 'show') {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onWindowClose() => windowManager.hide();
}
