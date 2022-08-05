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

/// Simple extension to stdout to hide the terminal curosr.
extension StdoutCursor on Stdout {
  /// When added to the stdout; moves the cursor really far to the left.
  void moveFarLeft() => stdout.write('\x1B[900D');

  /// Hides the terminal cursor.
  ///
  /// You will want to have code wrapped in a try-finally block:
  ///
  /// ```
  /// try{
  ///   stdout.hideCursor();
  /// } finally {
  ///   stdout.showCursor();
  /// }
  /// ```
  void hideCursor() => stdout.write('\x1b[?25l');

  /// Shows the terminal cursor.
  ///
  /// You will want to have code wrapped in a try-finally block:
  ///
  /// ```
  /// try{
  ///   stdout.hideCursor();
  /// } finally {
  ///   stdout.showCursor();
  /// }
  /// ```
  void showCursor() => stdout.write('\x1b[?25h');
}
