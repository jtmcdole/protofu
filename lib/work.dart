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

import 'package:protofu/compile_protos.dart';
import 'package:protofu/cursor.dart';
import 'package:protofu/process_deps.dart';
import 'package:protofu/spinner.dart';

/// Discovery and process dependencies before eventually compiling protos.
Future<void> doWork(Set<String> processed, List<String> baseArguments) async {
  final work = <String>{};
  for (var proto in processed) {
    work.addAll(await processDeps(proto, baseArguments));
  }

  stdout.writeln('processed ${processed.length} initial protos');

  // work contains the starting point for compilation - it will contain
  // all protos in our default zone, but maybe some protos outside (included)
  //
  // So we need to find more work.
  //
  // Loops Detection: Not implemented yet; pull requests welcomed
  var todo = work.difference(processed);

  final depsFuture = () async {
    while (todo.isNotEmpty) {
      for (var path in todo) {
        // something something test for loops
        processed.add(path);
        work.addAll(await processDeps(path, baseArguments));
      }
      todo = work.difference(processed);
    }
  }();

  try {
    await waitForTask('discover dependencies', depsFuture);
    stdout.writeln('compiling ${work.length} protos');
    await compileProtos(work, baseArguments);
  } finally {
    stdout.showCursor();
  }
}
