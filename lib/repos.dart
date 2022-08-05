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

/// Defines the base interface for all external repositories and how they
/// can be [fetch].
abstract class Repo {
  String get cache;

  /// Future that completes when the repository is available
  /// in the [cacheDirectory].
  Future<void> fetch();
}

/// Repository on disk somewhere (no work to be done).
class LocalRepo extends Repo {
  @override
  final String cache;

  LocalRepo(this.cache);

  @override
  String toString() => 'local($cache)';

  @override
  Future<void> fetch() async {
    // no op
  }
}
