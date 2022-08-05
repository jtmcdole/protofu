# Example

Run the following:

```console
dart pub global activate protofu
protofu
```

Or

```console
dart ../bin/protofu.dart
```

ProtoFu will read the `protofu.yaml` file, download `protoc`, the dart plugin,
and `googleapis`. Then it will process the `proto/*` folder and compile all
outputs into `lib/src/generated`.
