# ProtoFu - let me compile that for you

ProtoFu exists to make working with protobufs easier. Gone are the days of downloading
`protoc` and the dart `protoc_plugin`. We make it easier to download and depend, compile,
and keeping track of other proto repositories (`googleapis` as an example).

**Note**: This is not an officially supported Google product

ProtoFu will (through `protobuf.yaml` configuration)

* Download the version of `protoc` you define or a sensible version.
* Download the version of `protoc_plugin`.
* Clone protobufs libraries from github - assuming you have git installed.
* Reference protobuf libraries in relative or absolute paths.
* Process your protobufs to discover their transitive dependencies.
* Compile all the protobufs into a configurable `lib/src/generated` folder.

At least, that's the hope.

Example runs:
[![asciicast](https://asciinema.org/a/512092.svg)](https://asciinema.org/a/512092)

Check out [protofu.yaml](example/protofu.yaml) for template yaml.

Eventual goal:

[x] `dart pub global activate protofu`
[x] `protofu` then helps you.

## Use protofu within the dart build runner
### Example
```
pubspec.yaml:
  dev_dependencies:
    build_runner: ^2.13.1
    protofu: <recent version>
    protoc_plugin: ^21.1.2

  build.yaml:
      builders:
        protofu:
          options:
            protobuf_version: "27.5"
            use_protoc_plugin_from_pubspec: true
            root_dir: "proto/"
            proto_paths:
              - "proto/"
            out_dir: "lib/proto"
            grpc: false
            precompile_protoc_plugin: true
```

> **Note:** If you change `root_dir` or `out_dir` from their defaults, you must also override `build_extensions` in your `build.yaml` to match. Otherwise `build_runner` will not correctly track which files the builder produces.
>
> Example — if you set `root_dir: "protos/"` and `out_dir: "lib/generated/"`:
> ```yaml
> builders:
>   protofu:
>     build_extensions: {"protos/{{}}.proto": ["lib/generated/{{}}.pb.dart", "lib/generated/{{}}.pbenum.dart", "lib/generated/{{}}.pbserver.dart"]}
>     options:
>       root_dir: "protos/"
>       out_dir: "lib/generated/"
> ```



