import 'dart:async';
import 'package:logging/logging.dart';
import 'package:stacktrace_impl/stacktrace_impl.dart';

import 'util/dcli_platform.dart';

class Settings {
  /// Returns a singleton providing
  /// access to DCli settings.
  factory Settings() => _self ??= Settings._init();

  Settings._init();

  final logger = Logger('dcli');
  static Settings? _self;

  bool _verbose = false;

  /// returns true if the -v (verbose) flag was set on the
  /// dcli command line.
  /// e.g.
  /// dcli -v clean
  bool get isVerbose => _verbose;

  // ignore: cancel_subscriptions
  static StreamSubscription<LogRecord>? listener;

  /// Turns on verbose logging.
  void setVerbose({required bool enabled}) {
    _verbose = enabled;

    // ignore: flutter_style_todos
    /// TODO(bsutton): this affects everyones logging so
    /// I'm uncertain if this is a problem.
    hierarchicalLoggingEnabled = true;

    if (enabled) {
      logger.level = Level.INFO;
      listener ??= logger.onRecord.listen((record) {
        print('${record.level.name}: ${record.time}: ${record.message}');
      });
    } else {
      logger.level = Level.OFF;
      if (listener != null) {
        listener!.cancel();
        listener = null;
      }
    }
  }

  /// Logs a message to the console if the verbose
  /// settings are on.
  void verbose(String? message, {Stackframe? frame}) {
    final Stackframe calledBy;
    if (frame == null) {
      final st = StackTraceImpl();
      calledBy = st.frames[2];
    } else {
      calledBy = frame;
    }

    /// We log at info level (as that is logger's default)
    /// so that verbose messages will print when verbose
    /// is enabled.
    Logger('dcli').info('${calledBy.sourceFile}:${calledBy.lineNo} $message');
  }

  Stream<LogRecord> captureLogOutput() => logger.onRecord;

  void clearLogCapture() {
    logger.clearListeners();
  }

  /// True if you are running on a Mac.
  bool get isMacOS => DCliPlatform().isMacOS;

  /// True if you are running on a Linux system.
  bool get isLinux => DCliPlatform().isLinux;

  /// True if you are running on a Window system.
  bool get isWindows => DCliPlatform().isWindows;
}

///
/// If Settings.isVerbose is true then
/// this method will call [callback] to
/// get a String which will be logged to the
/// console or the log file set via the verbose command line
/// option.
///
/// This method is more efficient than calling Settings.verbose
/// as it will only build the string if verbose is enabled.
///
/// ```dart
/// verbose(() => 'Log the users name $user');
///
void verbose(String Function() callback) {
  if (Settings().isVerbose) {
    Settings().verbose(callback());
  }
}
