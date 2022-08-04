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
import 'package:path/path.dart' as path;

late String protoc;
late String dartPlugin;

final temporaryDirectory =
    Directory(path.join('.dart_tool', 'build', 'protoc_builder'));

final compilerDirectory =
    Directory(path.join(temporaryDirectory.path, 'compiler'));

final googleProtobufs = Directory(path.join(compilerDirectory.path, 'include'));

final pluginDirectory = Directory(path.join(temporaryDirectory.path, 'plugin'));

final cacheDirectory = Directory(path.join(temporaryDirectory.path, 'cache'));
