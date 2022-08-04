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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:protofu/paths.dart';
import 'package:protofu/progress_bar.dart';
import 'package:protofu/spinner.dart';
import 'package:protofu/unzip.dart';

Future<void> downloadProtoc(String version) async {
  final platformString = {
        'windows': 'win64',
        'macos': 'osx-x86_64',
        'linux': 'linux-x86_64'
      }[Platform.operatingSystem] ??
      'unsupported';
  if (platformString == 'unsupported') throw 'unsupported platform';
  final protocExe = Platform.isWindows ? 'protoc.exe' : 'protoc';
  final downloadUri =
      Uri.parse('https://github.com/protocolbuffers/protobuf/releases/'
          'download/v$version/protoc-$version-$platformString.zip');

  protoc = path.join(compilerDirectory.path, 'bin', protocExe);
  if (await File(protoc).exists()) {
    return;
  }

  stdout.write('[${progressBar(0, colorCompleted: penDone)}] '
      'downloading dart protoc plugin');
  final bytes = await getWithProgress(downloadUri, (progress) {
    final bar = progressBar(progress, colorCompleted: penDone);
    stdout.write('\x1B[900D[$bar]');
  });
  final bar = progressBar(1.0, colorCompleted: penDone);
  stdout.write('\x1B[900D[$bar]');
  stdout.writeln();

  stdout.write(
      '\x1B[900D[${progressBar(0, colorCompleted: penDone)}] uncompressing protoc');
  await unzip(bytes, compilerDirectory.path, progress: (progress) {
    stdout
        .write('\x1B[900D[${progressBar(progress, colorCompleted: penDone)}]');
  });
  stdout.writeln();

  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', protoc]);
  }
}

bool pluginWhere(String file) {
  final segments = path.split(file);
  return segments.contains('protoc_plugin') || segments.contains('protobuf');
}

Future<void> downloadDartPlugin(String version) async {
  final dartExeName =
      Platform.isWindows ? 'protoc-gen-dart.bat' : 'protoc-gen-dart';
  final localPluginPath = path.join(
    pluginDirectory.path,
    'protobuf.dart-protoc_plugin-v$version',
    'protoc_plugin',
  );

  dartPlugin = path.join(localPluginPath, 'bin', dartExeName);
  if (await File(dartPlugin).exists()) {
    return;
  }

  final downloadUri =
      Uri.parse('https://github.com/google/protobuf.dart/archive/'
          'refs/tags/protoc_plugin-v$version.zip');

  stdout.write('[${progressBar(0, colorCompleted: penDone)}] '
      'downloading dart protoc plugin');
  final bytes = await getWithProgress(downloadUri, (progress) {
    final bar = progressBar(progress, colorCompleted: penDone);
    stdout.write('\x1B[900D[$bar]');
  });
  stdout.write('\x1B[900D[${progressBar(1.0, colorCompleted: penDone)}]');
  stdout.writeln();

  stdout.write('[${progressBar(0, colorCompleted: penDone)}] '
      'uncompressing dart protoc plugin');
  await unzip(
    bytes,
    pluginDirectory.path,
    where: pluginWhere,
    progress: (progress) {
      stdout.write(
          '\x1B[900D[${progressBar(progress, colorCompleted: penDone)}]');
    },
  );
  stdout.writeln();

  // Fetch build deps from thirdparty package.
  await doLongTask('fetch plugin dart packages',
      Process.run('dart', ['pub', 'get'], workingDirectory: localPluginPath));

  // Compile program for higher performance.
  await doLongTask(
      'compiling protoc_plugin.dart for speed',
      Process.run('dart', ['compile', 'exe', 'bin/protoc_plugin.dart'],
          workingDirectory: localPluginPath));

  // Replace the "script" with the compiled excutible. Dart always outputs.exe
  final protocBin = path.join(localPluginPath, 'bin', 'protoc_plugin.exe');
  await File(protocBin).rename(dartPlugin);

  // Mark as executible when needed.
  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', '$localPluginPath/bin/protoc-gen-dart']);
  }
}

Future<Uint8List> getWithProgress(Uri url, void Function(num) progress) async {
  final client = http.Client();
  final response = await client.send(http.Request('GET', url));

  if (response.statusCode != 200) {
    throw 'error fetching $url ${response.statusCode}';
  }
  final size = response.contentLength ?? -1;
  int count = 0;

  final completer = Completer<Uint8List>();
  final sink = ByteConversionSink.withCallback(
      (data) => completer.complete(Uint8List.fromList(data)));

  response.stream.listen(
    (bytes) {
      count += bytes.length;
      progress(size == -1 ? -1 : count / size);
      sink.add(bytes);
    },
    onDone: sink.close,
    onError: completer.completeError,
    cancelOnError: true,
  );

  return completer.future;
}
