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

import 'package:protofu/paths.dart';
import 'package:path/path.dart' as path;
import 'package:protofu/repos.dart';

/// Repository of Protos from Git
///
/// NOTE: Requires `git` tool on the path.
/// NOTE: Only handles shallow checkouts right now.
class GitRepo implements Repo {
  final String url;
  final String? ref;

  @override
  late final String cache;

  GitRepo(this.url, this.ref) {
    cache = path.join(cacheDirectory.path, path.split(url).last);
  }

  @override
  Future<void> fetch() async {
    if (await Directory(cache).exists()) {
      return;
    }

    var result = await Process.run(
        'git', 'clone --depth 1 $url $cache'.split(' '),
        stdoutEncoding: utf8);
    if (result.exitCode != 0) {
      stderr.writeln('error cloning repo');
      stderr.write(result.stdout);
      stderr.write(result.stderr);
      exit(1);
    }

    if (ref != null) {
      result = await Process.run(
        'git',
        'checkout $ref'.split(' '),
        stdoutEncoding: utf8,
        workingDirectory: cache,
      );
      if (result.exitCode != 0) {
        stderr.writeln('error checkingout $ref');
        stderr.write(result.stdout);
        stderr.write(result.stderr);
        exit(1);
      }
    }
  }

  @override
  String toString() => 'git($url, $ref)';
}
