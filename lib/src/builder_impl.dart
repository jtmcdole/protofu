import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:protofu/download_tools.dart';
import 'package:protofu/paths.dart';
import 'package:protofu/plugin_from_pubspec.dart';

/// A [Builder] that compiles `.proto` files to Dart using `protoc`.
///
/// Intended to be used via `build_runner`. Configure via `build.yaml` options:
/// - `root_dir` (default: `proto/`): directory containing `.proto` source files.
/// - `out_dir` (default: `lib/proto/`): output directory for generated Dart files.
/// - `grpc` (default: `false`): whether to generate gRPC stubs.
/// - `proto_paths` (default: `[root_dir]`): additional `-I` paths for `protoc`.
/// - `protobuf_version` (default: `27.5`): `protoc` version to download.
/// - `use_installed_protoc` (default: `false`): use system `protoc` instead of downloading.
/// - `use_protoc_plugin_from_pubspec` (default: `true`): resolve `protoc_plugin` from pubspec dependencies.
/// - `precompile_protoc_plugin` (default: `true`): AOT-compile the plugin for faster execution.
/// - `dart_plugin_version` (default: `21.1.2`): plugin version to download if not resolved from pubspec.
final class ProtofuBuilder implements Builder {
  final BuilderOptions _options;

  // Shared across all builder instances in the same process to avoid
  // redundant downloads/compilations when multiple .proto files are built.
  static Future<void>? _setupFuture;

  /// Creates a [ProtofuBuilder] with the given [options].
  ProtofuBuilder(this._options);

  String get _rootDir {
    final d = _options.config['root_dir'] as String? ?? 'proto/';
    return d.endsWith('/') ? d : '$d/';
  }

  String get _outDir {
    final d = _options.config['out_dir'] as String? ?? 'lib/proto/';
    return d.endsWith('/') ? d : '$d/';
  }

  bool get _grpc => _options.config['grpc'] as bool? ?? false;

  List<String> get _protoPaths {
    final paths = _options.config['proto_paths'];
    if (paths is List) return paths.cast<String>();
    return [_rootDir];
  }

  @override
  Map<String, List<String>> get buildExtensions {
    final outputs = [
      '$_outDir{{}}.pb.dart',
      '$_outDir{{}}.pbenum.dart',
      '$_outDir{{}}.pbserver.dart',
    ];
    if (_grpc) outputs.add('$_outDir{{}}.pbgrpc.dart');
    return {'$_rootDir{{}}.proto': outputs};
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    _setupFuture ??= _setup();
    await _setupFuture;

    // Register the input with the build system for proper change tracking.
    await buildStep.readAsBytes(buildStep.inputId);

    final inputPath = buildStep.inputId.path;
    final package = buildStep.inputId.package;

    // Compute the stem relative to rootDir (may include subdirectories).
    // e.g. "proto/google/foo.proto" with rootDir "proto/" -> stem "google/foo"
    final stem = inputPath.startsWith(_rootDir)
        ? inputPath.substring(_rootDir.length, inputPath.length - '.proto'.length)
        : p.basenameWithoutExtension(inputPath);

    final tempDir = await Directory.systemTemp.createTemp('protofu_');
    try {
      final grpcArg = _grpc ? 'grpc:' : '';
      final result = await Process.run(
        protoc,
        [
          ..._protoPaths.map((path) => '-I$path'),
          '--dart_out=$grpcArg${tempDir.path}/',
          '--plugin=protoc-gen-dart=$dartPlugin',
          inputPath,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (result.exitCode != 0) {
        throw Exception('protoc failed for $inputPath:\n${result.stderr}');
      }

      final suffixes = ['.pb.dart', '.pbenum.dart', '.pbserver.dart'];
      if (_grpc) suffixes.add('.pbgrpc.dart');

      for (final suffix in suffixes) {
        final tempFile = File(p.join(tempDir.path, '$stem$suffix'));
        if (await tempFile.exists()) {
          final outputId = AssetId(package, '$_outDir$stem$suffix');
          await buildStep.writeAsBytes(outputId, await tempFile.readAsBytes());
        }
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> _setup() async {
    final protocVersion =
        _options.config['protobuf_version'] as String? ?? '27.5';
    final useInstalledProtoc =
        _options.config['use_installed_protoc'] as bool? ?? false;
    final useFromPubspec =
        _options.config['use_protoc_plugin_from_pubspec'] as bool? ?? true;
    final precompile =
        _options.config['precompile_protoc_plugin'] as bool? ?? true;
    final pluginVersion =
        _options.config['dart_plugin_version'] as String? ?? '21.1.2';

    if (useInstalledProtoc) {
      protoc = 'protoc';
    } else {
      await downloadProtoc(protocVersion);
    }

    if (useFromPubspec) {
      final resolved = await resolvePluginFromPubspec(precompile);
      if (resolved != null) {
        dartPlugin = resolved;
        return;
      }
    }

    await downloadDartPlugin(pluginVersion);
  }
}
