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

import 'package:ansicolor/ansicolor.dart';

final penDone = AnsiPen()..green();

String progressBar(
  num percentComplete, {
  int width = 50,
  AnsiPen? colorCompleted,
  AnsiPen? colorRemainder,
  String fill = '=',
  String empty = ' ',
}) {
  percentComplete = percentComplete.clamp(0, 1.0);
  int count = (width * percentComplete).round();

  var done = fill * count;
  if (colorCompleted != null) {
    done = colorCompleted(done);
  }

  var remainder = empty * (width - count);
  if (colorRemainder != null) {
    remainder = colorRemainder(remainder);
  }
  return '$done$remainder';
}
