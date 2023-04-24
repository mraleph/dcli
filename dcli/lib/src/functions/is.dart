/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

import 'dart:io';

import 'package:dcli_core/dcli_core.dart' as core;
import 'package:posix/posix.dart' as posix;

import '../../dcli.dart';

///
/// Returns true if the given [path] points to a file.
/// If [path] is a link the link will be followed and
/// we report on the resolved path.
///
/// ```dart
/// isFile("~/fred.jpg");
/// ```
bool isFile(String path) => core.isFile(path);

/// Returns true if the given [path] is a directory.
///
/// If [path] is a link the link will be followed and
/// we report on the resolved path.
/// ```dart
/// isDirectory("/tmp");
///
/// ```
bool isDirectory(String path) => core.isDirectory(path);

/// Returns true if the given [path] is a symlink
///
/// // ```dart
/// isLink("~/fred.jpg");
/// ```
bool isLink(String path) => core.isLink(path);

/// Returns true if the given path exists.
/// It may be a file, directory or link.
///
/// If [followLinks] is true (the default) then [exists]
/// follows any links and returns true/false based on
/// whether the resolved path exists.
///
/// If [followLinks] is false then [exists] will return
/// true if [path] exist.
///
/// ```dart
/// if (exists("/fred.txt"))
/// ```
///
/// Throws [ArgumentError] if [path] is null or an empty string.
///
/// See:
///  * [isLink]
///  * [isDirectory]
///  * [isFile]
bool exists(String path, {bool followLinks = true}) =>
    core.exists(path, followLinks: followLinks);

/// Returns the datetime the path was last modified
///
/// [path[ can be either a file or a directory.
///
/// Throws a [DCliException] with a nested
/// [FileSystemException] if the file does not
/// exist or the operation fails.
DateTime lastModified(String path) => core.lastModified(path);

/// Sets the last modified datetime on the given the path.
///
/// [path] can be either a file or a directory.
///
/// Throws a [DCliException] with a nested
/// [FileSystemException] if the file does not
/// exist or the operation fails.

void setLastModifed(String path, DateTime lastModified) =>
    core.setLastModifed(path, lastModified);

/// Returns true if the passed [pathToDirectory] is an
/// empty directory.
/// For large directories this operation can be expensive.
bool isEmpty(String pathToDirectory) => core.isEmpty(pathToDirectory);

/// checks if the passed [path] (a file or directory) is
/// writable by the user that owns this process
bool isWritable(String path) => _Is().isWritable(path);

/// checks if the passed [path] (a file or directory) is
/// readable by the user that owns this process
bool isReadable(String path) => _Is().isReadable(path);

/// checks if the passed [path] (a file or directory) is
/// executable by the user that owns this process
bool isExecutable(String path) => _Is().isExecutable(path);

class _Is extends core.DCliFunction {
  /// checks if the passed [path] (a file or directory) is
  /// writable by the user that owns this process
  bool isWritable(String path) {
    core.verbose(() => 'isWritable: ${truepath(path)}');
    return _checkPermission(path, writeBitMask);
  }

  /// checks if the passed [path] (a file or directory) is
  /// readable by the user that owns this process
  bool isReadable(String path) {
    core.verbose(() => 'isReadable: ${truepath(path)}');
    return _checkPermission(path, readBitMask);
  }

  /// checks if the passed [path] (a file or directory) is
  /// executable by the user that owns this process
  bool isExecutable(String path) {
    core.verbose(() => 'isExecutable: ${truepath(path)}');
    return Settings().isWindows || _checkPermission(path, executeBitMask);
  }

  static const readBitMask = 0x4;
  static const writeBitMask = 0x2;
  static const executeBitMask = 0x1;

  /// Checks if the user permission to act on the [path] (a file or directory)
  /// for the given permission bit mask. (read, write or execute)
  bool _checkPermission(String path, int permissionBitMask) {
    core.verbose(
      () => '_checkPermission: ${truepath(path)} '
          'permissionBitMask: $permissionBitMask',
    );

    if (Settings().isWindows) {
      throw UnsupportedError(
        'permission checks are not currently supported on windows',
      );
    }

    final user = Shell.current.loggedInUser;

    int permissions;
    String groupName;
    String ownerName;
    bool other;
    bool group;
    bool owner;

    try {
      final stat0 = posix.stat(path);
      groupName = posix.getgrgid(stat0.gid).name;
      ownerName = posix.getUserNameByUID(stat0.uid);
      final mode = stat0.mode;
      if (permissionBitMask == writeBitMask) {
        other = mode.isOtherWritable;
        group = mode.isGroupWritable;
        owner = mode.isOwnerWritable;
      } else if (permissionBitMask == readBitMask) {
        other = mode.isOtherReadable;
        group = mode.isGroupReadable;
        owner = mode.isOwnerReadable;
      } else if (permissionBitMask == executeBitMask) {
        other = mode.isOtherExecutable;
        group = mode.isGroupExecutable;
        owner = mode.isOwnerExecutable;
      } else {
        throw posix.PosixException('Unexpected bitMask', -1);
      }
    } on posix.PosixException catch (_) {
      //e.g 755 tomcat bsutton
      final stat = 'stat -L -c "%a %G %U" "$path"'.firstLine!;
      final parts = stat.split(' ');
      permissions = int.parse(parts[0], radix: 8);
      groupName = parts[1];
      ownerName = parts[2];
      //  if (( ($PERM & 0002) != 0 )); then
      other = (permissions & permissionBitMask) != 0;
      group = (permissions & (permissionBitMask << 3)) != 0;
      owner = (permissions & (permissionBitMask << 6)) != 0;
    }

    var access = false;
    if (other) {
      // Everyone has write access
      access = true;
    } else if (group) {
      // Some groups have write access
      if (isMemberOfGroup(groupName)) {
        access = true;
      }
    } else if (owner) {
      if (user == ownerName) {
        access = true;
      }
    }
    return access;
  }

  /// Returns true if the owner of this process
  /// is a member of [group].
  bool isMemberOfGroup(String group) {
    core.verbose(() => 'isMemberOfGroup: $group');

    if (Settings().isWindows) {
      throw UnsupportedError(
        'isMemberOfGroup is not Not currently supported on windows',
      );
    }
    // get the list of groups this user belongs to.
    final groups = 'groups'.firstLine!.split(' ');

    // is the user a member of the file's group.
    return groups.contains(group);
  }
}
