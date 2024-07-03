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
import 'package:args/args.dart';
import 'package:protofu/download_tools.dart';
import 'package:protofu/git.dart';
import 'package:protofu/repos.dart';
import 'package:protofu/spinner.dart';
import 'package:protofu/work.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('protoc-version', abbr: 'p', defaultsTo: '3.12.4')
    ..addOption('dart-plugin-version', abbr: 'd', defaultsTo: '20.0.1')
    ..addFlag('grpc', abbr: 'g', defaultsTo: false)
    ..addFlag('help', abbr: 'h', help: 'this helpful text', negatable: false);

  late ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    printUsage(parser);
    stderr.writeln(e);
    exit(1);
  }

  if (results.wasParsed('help')) {
    printUsage(parser);
    exit(0);
  }

  final outFolderDefault = 'lib/src/generated';

  // construct config with defaults
  var config = Config(
      protocVersion: results['protoc-version'],
      dartPluginVersion: results['dart-plugin-version'],
      grpcEnabled: false,
      outFolder: outFolderDefault,
      disallowServices: false,
      fatalWarnings: false,
      experimentalAllowProto3Optional: false,
      errorFormat: 'gcc',
      includeImports: false,
      includeSourceInfo: false);

  var yaml = YamlMap();
  try {
    yaml = loadYaml(File('protofu.yaml').readAsStringSync());
  } catch (_) {}

  final processed = <String>{};

  await processYaml(yaml, config);
  if (results.wasParsed('protoc-version')) {
    config.protocVersion = results['protoc-version'];
  }
  if (results.wasParsed('protoc-version')) {
    config.dartPluginVersion = results['dart-plugin-version'];
  }
  if (results.wasParsed('grpc')) {
    config.grpcEnabled = results['grpc'];
  }

  await downloadProtoc(config.protocVersion);
  await downloadDartPlugin(config.dartPluginVersion);
  await processRepos(config);

  for (var dir in config.srcFolders) {
    for (var file in dir
        .listSync(recursive: true, followLinks: false)
        .where((f) => f.path.endsWith('.proto'))) {
      processed.add(file.path);
    }
  }

  final grpc = config.grpcEnabled ? 'grpc:' : '';

  await Directory(config.outFolder).create(recursive: true);

  final baseArguments = [
    ...config.ipaths.map((e) => '-I$e'),
    '--dart_out=$grpc${config.outFolder}',
  ];

  // add options if specified in config
  if (config.experimentalAllowProto3Optional) {
    baseArguments.add('--experimental_allow_proto3_optional');
  }

  if (config.disallowServices) {
    baseArguments.add('--disallow_services');
  }

  if (config.fatalWarnings) {
    baseArguments.add('--fatal_warnings');
  }

  baseArguments.add('--error_format=${config.errorFormat}');

  // add descriptor set out
  if (config.descriptorSetOutFile != null) {
    baseArguments.add('--descriptor_set_out=${config.descriptorSetOutFile}');

    // add descriptor set out options if defined
    if (config.includeImports) {
      baseArguments.add('include_imports');
    }

    if (config.includeSourceInfo) {
      baseArguments.add('--include_source_info');
    }
  }

  // add descriptor sets in
  if (config.descriptorSetInFiles.isNotEmpty) {
    // construct descriptor set in files string
    var descriptorSetInArg = "--descriptor_set_in=";

    for (var file in config.descriptorSetInFiles) {
      descriptorSetInArg += "${file.toString()}'";
    }

    // pass to baseArguments
    baseArguments.add(descriptorSetInArg);
  }

  await doWork(processed, baseArguments);
}

void printUsage(ArgParser parser) {
  stderr.write('''ProtoFu - Dart Proto Compiler Helper
${parser.usage}
''');
}

class Config {
  String protocVersion;
  String dartPluginVersion;
  bool grpcEnabled;
  bool disallowServices;
  bool fatalWarnings;
  bool experimentalAllowProto3Optional;
  String errorFormat;

  String outFolder;

  String? descriptorSetOutFile;
  bool includeImports;
  bool includeSourceInfo;

  final descriptorSetInFiles = <File>[];

  final srcFolders = <Directory>[];
  final ipaths = <String>[];

  final repos = <Repo>[];

  Config(
      {required this.protocVersion,
      required this.dartPluginVersion,
      required this.grpcEnabled,
      required this.disallowServices,
      required this.outFolder,
      required this.fatalWarnings,
      required this.experimentalAllowProto3Optional,
      required this.errorFormat,
      required this.includeImports,
      required this.includeSourceInfo});

  @override
  String toString() => 'Config${{
        'protocVersion': protocVersion,
        'dartPluginVersion': dartPluginVersion,
        'grpcEnabled': grpcEnabled,
        'disallowServices': disallowServices,
        'fatalWarnings': fatalWarnings,
        'experimentalAllowProto3Optional': experimentalAllowProto3Optional,
        'errorFormat': errorFormat,
        'srcFolders': srcFolders,
        'outFolder': outFolder,
        'ipaths': ipaths,
        'repos': repos,
      }}';
}

Future processYaml(YamlMap yaml, Config config) async {
  if (yaml['compiler']?['version'] != null) {
    config.protocVersion = '${yaml['compiler']['version']}';
  }

  if (yaml['compiler']?['grpcEnabled'] != null) {
    config.grpcEnabled = yaml['compiler']?['grpcEnabled'];
  }

  if (yaml['plugin']?['version'] != null) {
    config.dartPluginVersion = '${yaml['plugin']['version']}';
  }

  if (yaml['sources'] == null) {
    stderr.writeln('missing source folder(s)');
    exit(1);
  } else if (yaml['sources'] is String) {
    final srcDir = Directory(yaml['sources']);
    if (!await srcDir.exists()) {
      stderr.writeln('missing source folder: $srcDir');
      exit(1);
    }
    config.srcFolders.add(srcDir);
    config.ipaths.add(srcDir.path);
  } else if (yaml['sources'] is YamlList) {
    for (var source in yaml['sources']) {
      if (source is! String) {
        stderr.writeln(
            'bad source rule in yaml - string entry expected: $source');
        exit(1);
      }
      final srcDir = Directory(source);
      if (!await srcDir.exists()) {
        stderr.writeln('missing source folder: $srcDir');
        exit(1);
      }
      config.srcFolders.add(srcDir);
      config.ipaths.add(srcDir.path);
    }
  } else {
    stderr.writeln('bad source rule in yaml - list or single entry expected');
    exit(1);
  }

  // Process options
  if (yaml['options']?['disallowServices'] != null) {
    config.disallowServices = yaml['options']?['disallowServices'];
  }

  if (yaml['options']?['experimentalAllowProto3Optional'] != null) {
    config.experimentalAllowProto3Optional =
        yaml['options']?['experimentalAllowProto3Optional'];
  }

  if (yaml['options']?['fatalWarnings'] != null) {
    config.fatalWarnings = yaml['options']?['fatalWarnings'];
  }

  if (yaml['options']?['errorFormat'] != null) {
    config.errorFormat = yaml['options']?['errorFormat'];
  }

  // Process descriptor sets settings
  if (yaml['descriptor']?['setIn'] != null) {
    if (yaml['descriptor']['setIn'] is String) {
      final descSetInFile = File(yaml['descriptor']['setIn']);
      if (!await descSetInFile.exists()) {
        stderr.writeln('missing descriptor set in file: $descSetInFile');
        exit(1);
      }
      config.descriptorSetInFiles.add(descSetInFile);
    } else if (yaml['descriptor']['setIn'] is YamlList) {
      for (var file in yaml['descriptor']['setIn']) {
        if (file is! String) {
          stderr.writeln(
              'bad source rule in yaml - string entry expected: $file');
          exit(1);
        }
        final descSetInFile = File(file);
        if (!await descSetInFile.exists()) {
          stderr.writeln('missing source folder: $descSetInFile');
          exit(1);
        }
        config.descriptorSetInFiles.add(descSetInFile);
      }
    } else {
      stderr.writeln(
          'Descriptor Set In: Bad source rule in yaml - list or single entry expected');
      exit(1);
    }
  }

  if (yaml['descriptor']?['setOut'] != null) {
    config.descriptorSetOutFile = yaml['descriptor']?['setOut'];
  }

  // Process the output directory
  if (yaml['output'] != null) {
    config.outFolder = yaml['output'];
  }

  /// Process the include directives - git requires cloning.
  if (yaml['include'] == null) return;
  if (yaml['include'] is! YamlList) {
    stderr.writeln('includes expected to be a list');
    exit(1);
  }
  for (var include in yaml['include'] as YamlList) {
    if (include is YamlMap && include.containsKey('git')) {
      final git = include['git'];
      if (git is! YamlMap || git['url'] is! String) {
        stderr.writeln('git node required to be map with string `url`');
        exit(1);
      }
      final url = git['url'] as String;
      final ref = git['ref'];
      if (ref != null && ref is! String) {
        stderr.writeln('optional git `ref` required to be a string');
        exit(1);
      }
      config.repos.add(GitRepo(url, ref));
      continue;
    }
    if (include is String) {
      if (!await Directory(include).exists()) {
        stderr.writeln('include path does not exist: $include');
        exit(1);
      }
      config.repos.add(LocalRepo(include));
    }
  }
}

Future processRepos(Config config) async {
  if (config.repos.isEmpty) return;
  await waitForTask('loading third_party repos', () async {
    for (var repo in config.repos) {
      await repo.fetch();
      config.ipaths.add(repo.cache);
    }
  }());
}
