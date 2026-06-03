import 'package:build/build.dart';
import 'package:protofu/src/builder_impl.dart';

/// Returns a [Builder] that compiles `.proto` files to Dart using `protoc`.
///
/// Intended to be used via `build_runner`; registered in `build.yaml`.
Builder getBuilder(BuilderOptions options) => ProtofuBuilder(options);
