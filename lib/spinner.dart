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

import 'package:meta/meta.dart';
import 'package:protofu/cursor.dart';

@visibleForTesting
const spinnerGlyphs = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

String spinner(int counter) => spinnerGlyphs[counter % spinnerGlyphs.length];

class Spinner {
  int count = 0;
  String tick() => spinner(count++);
}

Future doLongTask(String description, Future otherWork) async {
  if (!description.endsWith(' ')) {
    description = '$description ';
  }
  stdout.write(description);
  try {
    stdout.hideCursor();
    final spinner = Spinner();
    bool done = false;
    stdout.write(spinner.tick());
    final tickerFuture = () async {
      while (!done) {
        stdout.write('\x1B[D${spinner.tick()}');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }();

    await otherWork;
    done = true;
    await tickerFuture;
    stdout.write('\x1B[D✔️');
    stdout.writeln();
  } finally {
    stdout.showCursor();
  }
}
