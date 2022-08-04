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
import 'package:protofu/progress_bar.dart';

Future<void> compileProtos(
    Set<String> protos, List<String> baseArguments) async {
  int counter = 0;

  void writeStatusBar(String file) {
    final bar = progressBar(counter / protos.length, colorCompleted: penDone);
    stdout.write('\x1B[900D[$bar] ($counter / ${protos.length}) - $file');
  }

  for (var proto in protos) {
    counter++;
    writeStatusBar(path.basename(proto));
    final depsProcess = await Process.run(
      protoc,
      [
        ...baseArguments,
        '--plugin=protoc-gen-dart=$dartPlugin',
        proto,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (depsProcess.exitCode != 0) {
      stderr.writeln('error compiling: $proto');
      stderr.writeln(depsProcess.stderr);
      throw 'error';
    }
  }
  stdout.writeln();
}
