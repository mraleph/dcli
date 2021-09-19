import 'package:dcli_core/dcli_core.dart' as core;

import '../../dcli.dart';
import '../settings.dart';
import '../util/progress.dart';

///
/// Returns count [lines] from the end of the file at [path].
///
/// ```dart
/// tail('/var/log/syslog', 10).forEach((line) => print(line));
/// ```
///
/// Throws a [TailException] exception if [path] is not a file.
///
Progress tail(String path, int lines) => _Tail().tail(path, lines);

class _Tail extends core.DCliFunction {
  Progress tail(String path, int lines, {Progress? progress}) {
    verbose(() => 'tail ${truepath(path)} lines: $lines');

    if (!exists(path)) {
      throw TailException('The path ${truepath(path)} does not exist.');
    }

    if (!isFile(path)) {
      throw TailException('The path ${truepath(path)} is not a file.');
    }

    try {
      progress ??= Progress.printStdOut();

      waitForEx(
        core.withOpenLineFile(path, (file) async {
          file.readAll().listen((line) async {
            progress!.addToStdout(line);
          });
        }),
      );
    }
    // ignore: avoid_catches_without_on_clauses
    catch (e) {
      throw TailException(
        'An error occured reading ${truepath(path)}. Error: $e',
      );
    } finally {
      progress!.close();
    }

    return progress;
  }
}

/// thrown when the [tail] function encounters an exception
class TailException extends core.DCliFunctionException {
  /// thrown when the [tail] function encounters an exception
  TailException(String reason) : super(reason);
}
