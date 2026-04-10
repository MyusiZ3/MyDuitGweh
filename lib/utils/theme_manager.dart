import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> notifier = ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('app_theme_mode_index') ?? 0;
    if (index >= 0 && index < ThemeMode.values.length) {
      notifier.value = ThemeMode.values[index];
    }
    _updateSystemOverlay();
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_mode_index', mode.index);
    notifier.value = mode;
    _updateSystemOverlay();
  }

  static void _updateSystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      isDarkMode
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  static bool get isDarkMode {
    if (notifier.value == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return notifier.value == ThemeMode.dark;
  }
}
