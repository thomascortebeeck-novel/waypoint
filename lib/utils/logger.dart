import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Small tagged logger around debugPrint so we can filter easily in the console.
/// Use logI/logW/logE for consistency and to include timestamps.
class Log {
  static void i(String tag, String message) => _print('I', tag, message);
  static void w(String tag, String message) => _print('W', tag, message);
  static void e(String tag, String message, [Object? error, StackTrace? stack]) {
    final msg = error == null ? message : '$message — error: $error';
    _print('E', tag, msg, stack);
  }

  static void _print(String level, String tag, String message, [StackTrace? stack]) {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts][$level][$tag] $message';
    debugPrint(line);
    if (stack != null) developer.log(message, name: tag, level: 1000, stackTrace: stack);
  }
}
