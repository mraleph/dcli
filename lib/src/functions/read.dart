import 'dart:convert';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart' as core;

import '../../dcli.dart';
import '../settings.dart';
import '../util/progress.dart';
import '../util/wait_for_ex.dart';

/// Reads lines from the file at [path].
/// ```dart
/// read('/var/log/syslog').forEach((line) => print(line));
/// ```
///
/// [delim] sets the line delimiter which defaults to newline
///
/// If the file does not exists then a ReadException is thrown.
///
Progress read(String path, {String delim = '\n'}) =>
    _Read().read(path, delim: delim);

/// Read lines from stdin
Progress readStdin() => _Read()._readStdin();

class _Read extends core.DCliFunction {
  Progress read(String path, {String delim = '\n', Progress? progress}) {
    final sourceFile = File(path);

    verbose(() => 'read: ${truepath(path)}, delim: $delim');

    if (!exists(path)) {
      throw ReadException('The file at ${truepath(path)} does not exists');
    }

    progress ??= Progress.devNull();

    waitForEx<void>(
      sourceFile
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
        progress!.addToStdout(line);
      }),
    );

    progress.close();

    return progress;
  }

  Progress _readStdin({Progress? progress}) {
    verbose(() => 'readStdin');

    try {
      progress ??= Progress.devNull();
      String? line;

      while ((line = stdin.readLineSync()) != null) {
        progress.addToStdout(line!);
      }
    } finally {
      progress!.close();
    }

    return progress;
  }
}

/// Thrown when the [read] function encouters an error.
class ReadException extends core.DCliFunctionException {
  /// Thrown when the [read] function encouters an error.
  ReadException(String reason, [StackTraceImpl? stacktrace])
      : super(reason, stacktrace);
}
