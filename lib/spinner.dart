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

/// Returns a [spinnerGlyphs] for [counter].
String spinner(int counter) => spinnerGlyphs[counter % spinnerGlyphs.length];

/// Waits for [otherWork], a long running task to complete while rendering
/// a spinner to the screen with [description].
Future waitForTask(String description, Future otherWork) async {
  if (!description.endsWith(' ')) {
    description = '$description ';
  }
  stdout.write(description);
  try {
    stdout.hideCursor();
    int count = 0;
    bool done = false;
    stdout.write(spinner(count++));
    final tickerFuture = () async {
      while (!done) {
        stdout.write('\x1B[D${spinner(count++)}');
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
