import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> with _Logger {
  ThemeNotifier() : super(ThemeMode.light);
}

mixin _Logger on StateNotifier<ThemeMode> {
  void log(String message) {
    debugPrint('ThemeNotifier: $message');
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});
