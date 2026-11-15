/// Raw package_config.json contents and where it was read from.
class RawPackageConfig {
  /// Creates a raw config.
  const RawPackageConfig(this.uri, this.json);

  /// Location of the file (used to resolve relative `rootUri`s).
  final Uri uri;

  /// File contents.
  final String json;
}

/// No file system here (web): nothing to read.
RawPackageConfig? readPackageConfig() => null;

/// No environment here (web).
String? pubCacheFromEnvironment() => null;
