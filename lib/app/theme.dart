import 'package:flutter/material.dart';

abstract final class AtMeetColors {
  static const black = Color(0xFF050506);
  static const panel = Color(0xFF111214);
  static const bubble = Color(0xFF1D2024);
  static const blue = Color(0xFF74B9FF);
  static const electricBlue = Color(0xFF087DFF);
  static const orange = Color(0xFFFF3B16);
  static const silver = Color(0xFFE5E5E2);
  static const muted = Color(0xFF8B9099);
}

abstract final class AtMeetTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AtMeetColors.electricBlue,
      brightness: Brightness.dark,
      surface: AtMeetColors.panel,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AtMeetColors.black,
      fontFamily: '.SF Pro Text',
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF151619),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AtMeetColors.blue,
        selectionColor: Color(0x5574B9FF),
      ),
    );
  }
}
