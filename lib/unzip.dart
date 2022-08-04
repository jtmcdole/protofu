// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

bool _anyWhere(_) => true;

Future<void> unzip(
  List<int> bytes,
  String target, {
  bool Function(String path) where = _anyWhere,
  void Function(num progress)? progress,
}) async {
  final archive = ZipDecoder().decodeBytes(bytes);
  final int files = archive.length;
  int count = 1;
  for (final file in archive) {
    final filename = file.name;
    if (progress != null) progress(count++ / files);
    if (file.isFile && where(file.name)) {
      final fileHandle = File(path.join(target, filename));
      await fileHandle.create(recursive: true);
      await fileHandle.writeAsBytes(file.content as List<int>);
    }
  }
}
