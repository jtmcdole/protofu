import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:protofu/paths.dart';

/// Resolves [protoc_plugin] from the current project's package_config and
/// compiles it to a native executable for use with protoc.
///
/// Returns the path to the compiled executable, or null if [protoc_plugin]
/// is not listed as a dependency in the current project.
Future<String?> resolvePluginFromPubspec(bool precompile) async {
  final packageConfig = await findPackageConfig(Directory.current);
  if (packageConfig == null) return null;

  for (final package in packageConfig.packages) {
    if (package.name == 'protoc_plugin') {
      final pluginRoot = package.root.toFilePath();
      return precompile
          ? await _compilePlugin(pluginRoot)
          : await _dartRunWrapper(pluginRoot);
    }
  }

  return null;
}

/// Compiles [protoc_plugin] to a native executable and caches it under
/// `.dart_tool/build/protofu/plugin/pubspec/`.
Future<String> _compilePlugin(String pluginRoot) async {
  final exeName =
      Platform.isWindows ? 'protoc-gen-dart.exe' : 'protoc-gen-dart';
  final cacheDir = Directory(p.join(pluginDirectory.path, 'pubspec'));
  await cacheDir.create(recursive: true);
  final exePath = p.join(cacheDir.path, exeName);

  if (await File(exePath).exists()) return exePath;

  final scriptPath = p.join(pluginRoot, 'bin', 'protoc_plugin.dart');
  final packageConfigPath = p.join(
    Directory.current.path,
    '.dart_tool',
    'package_config.json',
  );
  final result = await Process.run(
    'dart',
    [
      'compile', 'exe', scriptPath,
      '-o', exePath,
      '--packages', packageConfigPath,
    ],
  );

  if (result.exitCode != 0) {
    throw Exception('Failed to compile protoc_plugin:\n${result.stderr}');
  }

  if (!Platform.isWindows) {
    await Process.run('chmod', ['+x', exePath]);
  }

  return exePath;
}

/// Creates a wrapper script that runs the plugin via `dart run` (slower than
/// precompiled, but avoids the compile step). The wrapper is cached under
/// `.dart_tool/build/protofu/plugin/pubspec/`.
///
/// On Unix a shell script is written; on Windows a `.bat` file. Both are
/// executable so `protoc --plugin=protoc-gen-dart=<path>` works correctly.
Future<String> _dartRunWrapper(String pluginRoot) async {
  final scriptPath = p.join(pluginRoot, 'bin', 'protoc_plugin.dart');
  final cacheDir = Directory(p.join(pluginDirectory.path, 'pubspec'));
  await cacheDir.create(recursive: true);

  if (Platform.isWindows) {
    final wrapperPath = p.join(cacheDir.path, 'protoc-gen-dart.bat');
    if (!await File(wrapperPath).exists()) {
      await File(wrapperPath).writeAsString('@echo off\ndart run "$scriptPath" %*\n');
    }
    return wrapperPath;
  } else {
    final wrapperPath = p.join(cacheDir.path, 'protoc-gen-dart');
    if (!await File(wrapperPath).exists()) {
      await File(wrapperPath)
          .writeAsString('#!/bin/sh\nexec dart run "$scriptPath" "\$@"\n');
      await Process.run('chmod', ['+x', wrapperPath]);
    }
    return wrapperPath;
  }
}
