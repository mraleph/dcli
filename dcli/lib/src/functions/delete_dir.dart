/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'package:dcli_core/dcli_core.dart' as core;

import '../../dcli.dart';

export 'package:dcli_core/dcli_core.dart' show DeleteDirException;

///
/// Deletes the directory located at [path].
///
/// If [recursive] is true (default true) then the directory and all child files
/// and directories will be deleted.
///
/// ```dart
/// deleteDir("/tmp/testing", recursive=true);
/// ```
///
/// If [path] is not a directory then a [DeleteDirException] is thrown.
///
/// If the directory does not exists a [DeleteDirException] is thrown.
///
/// If the directory cannot be delete (e.g. permissions) a
/// [DeleteDirException] is thrown.
///
/// If recursive is false the directory must be empty otherwise a
/// [DeleteDirException] is thrown.
///
/// See:
///  * [isDirectory]
///  * [exists]
///
void deleteDir(String path, {bool recursive = true}) =>
    core.deleteDir(path, recursive: recursive);
