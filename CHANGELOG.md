# Changelog

## 1.3.0

- Feature: `build_runner` integration via `ProtofuBuilder` (`lib/builder.dart`, `build.yaml`).
- Feature: Resolve `protoc_plugin` from the project's pubspec dependencies (`lib/plugin_from_pubspec.dart`).
- Feature: ARM architecture support for macOS, Linux, and Windows (`lib/download_tools.dart`).

## 1.2.1

- Fix: protoc plugin > 22.1.0 works

## 1.2.0

Udpate: pubspec.yaml packages
Update: example with latest plugin values
Fix: interpret `version` yaml values as strings

## 1.1.1

- Dart 3.0

## 1.0.2

- Added grpc option to protofu.yaml
- Expands options to protofu.yaml

## 1.0.1

- example/readme.md to make pub.dev happy

## 1.0.0

- Moved temporary directory to `.dart_tool/build/protofu`
- Added documentation even though its a tool?
- Moved `test` folder to `example`. Tests come later.
- Version bump - it works for shallow git checkouts and local references.

## 0.0.1-dev

- Initial version.
