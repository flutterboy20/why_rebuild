import 'dart:io';
import 'dart:isolate';

import 'package_config_stub.dart' show RawPackageConfig;

export 'package_config_stub.dart' show RawPackageConfig;

/// Reads the running isolate's package_config.json when it is on this
/// machine's disk (tests, desktop). Returns null on devices, where the file
/// stays on the host.
RawPackageConfig? readPackageConfig() {
  final List<Uri> candidates = <Uri>[];
  try {
    final Uri? fromIsolate = Isolate.packageConfigSync;
    if (fromIsolate != null) {
      candidates.add(fromIsolate);
    }
  } catch (_) {
    // Not supported on this embedder.
  }
  try {
    candidates
        .add(Directory.current.uri.resolve('.dart_tool/package_config.json'));
  } catch (_) {
    // No current directory (sandboxed platforms).
  }
  for (final Uri uri in candidates) {
    try {
      if (uri.scheme != 'file' || !uri.path.endsWith('.json')) {
        continue;
      }
      final File file = File.fromUri(uri);
      if (file.existsSync()) {
        return RawPackageConfig(uri, file.readAsStringSync());
      }
    } catch (_) {
      // Unreadable: try the next candidate.
    }
  }
  return null;
}

/// The PUB_CACHE override, if set.
String? pubCacheFromEnvironment() {
  try {
    return Platform.environment['PUB_CACHE'];
  } catch (_) {
    return null;
  }
}
