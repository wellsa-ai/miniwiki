import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

/// Structured logging system for debugging and monitoring.
class AppLogger {
  static const _tag = '[miniwiki]';

  /// Log with level and context
  static void log(
    LogLevel level,
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final contextStr = context != null ? '[$context]' : '';
      final prefix = '$_tag $contextStr';

      switch (level) {
        case LogLevel.debug:
          debugPrint('$prefix [DEBUG] $timestamp — $message');
          break;
        case LogLevel.info:
          debugPrint('$prefix [INFO] $timestamp — $message');
          break;
        case LogLevel.warning:
          debugPrint('$prefix [WARN] $timestamp — $message');
          if (error != null) debugPrint('  Error: $error');
          break;
        case LogLevel.error:
          debugPrint('$prefix [ERROR] $timestamp — $message');
          if (error != null) debugPrint('  Error: $error');
          if (stackTrace != null) debugPrint('  Stack: $stackTrace');
          break;
        case LogLevel.critical:
          debugPrint('$prefix [CRITICAL] $timestamp — $message');
          if (error != null) debugPrint('  Error: $error');
          if (stackTrace != null) debugPrint('  Stack: $stackTrace');
          break;
      }
    }

    // TODO: Send to remote logging service in production
    // - Firebase Crashlytics
    // - Sentry
    // - Custom backend
  }

  // Convenience methods
  static void debug(String msg, {String? context}) =>
      log(LogLevel.debug, msg, context: context);

  static void info(String msg, {String? context}) =>
      log(LogLevel.info, msg, context: context);

  static void warning(String msg, {String? context, Object? error}) =>
      log(LogLevel.warning, msg, context: context, error: error);

  static void error(String msg, {String? context, Object? error, StackTrace? stack}) =>
      log(LogLevel.error, msg, context: context, error: error, stackTrace: stack);

  static void critical(String msg,
      {String? context, Object? error, StackTrace? stack}) =>
      log(LogLevel.critical, msg, context: context, error: error, stackTrace: stack);
}

/// Performance monitoring
class PerformanceMonitor {
  final String label;
  final DateTime _startTime = DateTime.now();

  PerformanceMonitor(this.label) {
    AppLogger.debug('Started: $label', context: 'Performance');
  }

  void stop() {
    final duration = DateTime.now().difference(_startTime);
    AppLogger.info(
      'Completed: $label (${duration.inMilliseconds}ms)',
      context: 'Performance',
    );
  }
}
