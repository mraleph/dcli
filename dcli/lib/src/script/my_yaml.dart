/* Copyright (C) S. Brett Sutton - All Rights Reserved
 * Unauthorized copying of this file, via any medium is strictly prohibited
 * Proprietary and confidential
 * Written by Brett Sutton <bsutton@onepub.dev>, Jan 2022
 */

// ignore_for_file: deprecated_member_use

import 'dart:cli';
import 'dart:io';

import 'package:yaml/yaml.dart' as y;
import '../pubspec/dependency.dart';

/// wrapper for the YamlDocument
/// designed to make it easier to read yaml files.
class MyYaml {
  /// read yaml from string
  MyYaml.fromString(String content) {
    _document = _load(content);
  }

  /// reads yaml from file.
  MyYaml.fromFile(String path) {
    final contents = File(path).readAsStringSync();
    _document = _load(contents);
  }

  y.YamlDocument _load(String content) => y.loadYamlDocument(content);

  late y.YamlDocument _document;

  /// returns the raw content of the yaml file.
  String get content => _document.toString();

  /// reads the project name from the yaml file
  ///
  String? getValue(String key) {
    if (_document.contents.value == null) {
      return null;
    } else {
      return (_document.contents.value as Map)[key] as String?;
    }
  }

  /// returns the list of elements attached to [key].
  y.YamlList? getList(String key) {
    if (_document.contents.value == null) {
      return null;
    } else {
      return (_document.contents.value as Map)[key] as y.YamlList?;
    }
  }

  /// returns the map of elements attached to [key].
  y.YamlMap? getMap(String key) {
    if (_document.contents.value == null) {
      return null;
    } else {
      return (_document.contents.value as Map)[key] as y.YamlMap?;
    }
  }

  /// addes a list to the yaml.
  void setList(String key, List<Dependency> list) {
    (_document.contents.value as Map)[key] = list;
  }
}
