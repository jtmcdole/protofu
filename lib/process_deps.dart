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

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:protofu/paths.dart';

Future<Set<String>> processDeps(String file, List<String> baseArguments) async {
  final work = <String>{};
  final tmpPath = path.join(temporaryDirectory.path, 'tmp.deps');
  final depsProcess = await Process.run(
    protoc,
    [
      '--dependency_out=$tmpPath',
      ...baseArguments,
      '--plugin=protoc-gen-dart=$dartPlugin',
      file,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (depsProcess.exitCode != 0) {
    stderr.writeln(depsProcess.stdout);
    stderr.writeln('error processing dependency: $file');
    stderr.writeln(depsProcess.stderr);
    throw 'error';
  }

  bool found = false;
  for (var line in LineSplitter.split(File(tmpPath).readAsStringSync())) {
    if (!found && line.contains(': ')) {
      found = true;
      var dep = line.split(': ')[1];
      if (dep.endsWith(r'\')) {
        dep = dep.substring(0, dep.length - 1);
      }
      work.add(dep.trim());
    } else if (found) {
      if (line.endsWith(r'\')) {
        line = line.substring(0, line.length - 1);
      }
      work.add(line.trim());
    }
  }
  return work;
}
