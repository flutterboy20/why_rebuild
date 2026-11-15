import 'dart:convert';

import 'package_config_stub.dart' if (dart.library.io) 'package_config_io.dart'
    as pc;

/// This package's own name. Its frames and widgets are never "app code".
const String selfPackage = 'why_rebuild';

/// Packages that ship with the Flutter SDK.
///
/// `listen` holds `ChangeNotifier` / `ValueNotifier` since Flutter 3.50 (it is
/// a dependency of `package:flutter`), so its frames are framework frames.
const Set<String> flutterSdkPackages = <String>{
  'flutter',
  'listen',
  'flutter_test',
  'flutter_localizations',
  'flutter_web_plugins',
  'flutter_driver',
  'integration_test',
  'sky_engine',
};

/// Test infrastructure; never "the caller" of a rebuild.
const Set<String> _infraPackages = <String>{
  'stack_trace',
  'test_api',
  'matcher',
  'fake_async',
};

/// `file:///C:/a%20b/x.dart`, `C:\a b\x.dart` -> `c:/a b/x.dart`.
String normalizePath(String s, {bool lower = true}) {
  String p = s;
  if (p.startsWith('file:')) {
    try {
      p = Uri.decodeFull(Uri.parse(p).path);
    } catch (_) {
      p = p.substring(5);
    }
  }
  p = p.replaceAll(r'\', '/');
  if (p.length > 2 && p[0] == '/' && p[2] == ':') {
    p = p.substring(1); // "/C:/x" -> "C:/x"
  }
  return lower ? p.toLowerCase() : p;
}

final RegExp _drivePath = RegExp(r'^[A-Za-z]:[\\/]');

/// True for `file:` URIs and absolute paths.
bool looksLikePath(String uri) =>
    uri.startsWith('file:') || uri.startsWith('/') || _drivePath.hasMatch(uri);

/// One entry of package_config.json.
class PackageEntry {
  /// Creates an entry.
  const PackageEntry(this.name, this.root, this.libOriginal, this.local);

  /// Package name.
  final String name;

  /// Normalized (lower-case) root directory, ending with `/`.
  final String root;

  /// Normalized, case-preserved `lib/` directory, ending with `/`.
  final String libOriginal;

  /// Lower-case [libOriginal].
  String get lib => libOriginal.toLowerCase();

  /// True when the package lives in the project (relative `rootUri`), i.e.
  /// it is the developer's own code rather than a pub-cache or SDK package.
  final bool local;
}

/// Decides whether a stack frame URI or a widget creation file is app code,
/// third-party code, the Flutter SDK, or this scanner, and shortens paths for
/// display.
///
/// Exact when package_config.json is readable (tests, desktop): a package is
/// app code iff its `rootUri` is relative. On devices the file stays on the
/// host, so it falls back to the app package name plus pub-cache path
/// heuristics.
class CodeOrigin {
  CodeOrigin._(
      this.appPackage, this._packages, this._projectRoot, this._pubCache)
      : _localNames = <String>{
          for (final PackageEntry e in _packages)
            if (e.local) e.name,
        },
        _byName = <String, PackageEntry>{
          for (final PackageEntry e in _packages) e.name: e,
        } {
    _packages.sort((PackageEntry a, PackageEntry b) =>
        b.root.length.compareTo(a.root.length));
    _selfLib = _byName[selfPackage]?.lib;
  }

  /// Detects the app package and reads package_config.json when possible.
  ///
  /// [stack] is the `install()` caller's stack, used when neither
  /// [appPackage] nor package_config.json names the app.
  factory CodeOrigin.detect({String? appPackage, String? stack}) {
    List<PackageEntry> packages = <PackageEntry>[];
    String? projectRoot;
    String? rootPackage;
    final pc.RawPackageConfig? raw = pc.readPackageConfig();
    if (raw != null) {
      try {
        projectRoot = normalizePath(raw.uri.resolve('../').toString());
        packages = parsePackageConfig(raw.uri, raw.json);
        for (final PackageEntry e in packages) {
          if (e.root == projectRoot) {
            rootPackage = e.name;
          }
        }
      } catch (_) {
        packages = <PackageEntry>[];
        projectRoot = null;
      }
    }
    final String? fromStack = stack == null ? null : packageFromStack(stack);
    final String? app = appPackage ?? rootPackage ?? fromStack;
    // A config read from the current directory may belong to another
    // project. Only trust it if it knows the app.
    if (app != null &&
        packages.isNotEmpty &&
        !packages.any((PackageEntry e) => e.name == app)) {
      packages = <PackageEntry>[];
      projectRoot = null;
    }
    final String? pubCache = pc.pubCacheFromEnvironment();
    return CodeOrigin._(
      app,
      packages,
      projectRoot,
      pubCache == null || pubCache.isEmpty ? null : normalizePath(pubCache),
    );
  }

  /// Builds an origin from explicit data (tests).
  factory CodeOrigin.manual({
    String? appPackage,
    List<PackageEntry> packages = const <PackageEntry>[],
    String? projectRoot,
  }) =>
      CodeOrigin._(
          appPackage, List<PackageEntry>.of(packages), projectRoot, null);

  /// The app's package name, e.g. `my_app`.
  final String? appPackage;

  final List<PackageEntry> _packages;
  final Set<String> _localNames;
  final Map<String, PackageEntry> _byName;
  final String? _projectRoot;
  final String? _pubCache;
  String? _selfLib;
  final Map<String, bool> _appCache = <String, bool>{};

  /// True when package_config.json was read (exact detection).
  bool get exact => _packages.isNotEmpty;

  /// Parses package_config.json.
  static List<PackageEntry> parsePackageConfig(Uri configUri, String json) {
    final Object? decoded = jsonDecode(json);
    final List<PackageEntry> result = <PackageEntry>[];
    if (decoded is! Map<String, Object?>) {
      return result;
    }
    final Object? list = decoded['packages'];
    if (list is! List<Object?>) {
      return result;
    }
    for (final Object? p in list) {
      if (p is! Map<String, Object?>) {
        continue;
      }
      final Object? name = p['name'];
      final Object? rootUri = p['rootUri'];
      if (name is! String || rootUri is! String) {
        continue;
      }
      final Object? packageUri = p['packageUri'];
      final String rootText = rootUri.endsWith('/') ? rootUri : '$rootUri/';
      final Uri root = configUri.resolve(rootText);
      final Uri lib = root.resolve(packageUri is String ? packageUri : 'lib/');
      String libText = normalizePath(lib.toString(), lower: false);
      if (!libText.endsWith('/')) {
        libText = '$libText/';
      }
      result.add(PackageEntry(
        name,
        normalizePath(root.toString()),
        libText,
        !Uri.parse(rootUri).hasScheme,
      ));
    }
    return result;
  }

  /// First `package:` frame in [stack] that is not the SDK, test
  /// infrastructure, or this scanner.
  static String? packageFromStack(String stack) {
    final RegExp re = RegExp(r'package:([A-Za-z0-9_]+)/');
    for (final String line in stack.split('\n')) {
      final RegExpMatch? m = re.firstMatch(line);
      if (m == null) {
        continue;
      }
      final String name = m.group(1)!;
      if (name == selfPackage ||
          flutterSdkPackages.contains(name) ||
          _infraPackages.contains(name)) {
        continue;
      }
      return name;
    }
    return null;
  }

  static final RegExp _selfPathRe = RegExp(r'/why_rebuild(-[^/]*)?/lib/');
  static final RegExp _sdkPathRe = RegExp(
      r'/packages/(flutter|flutter_test|flutter_localizations|flutter_web_plugins|flutter_driver|integration_test)/lib/');

  String? _packageNameOf(String uri) {
    if (!uri.startsWith('package:')) {
      return null;
    }
    final int slash = uri.indexOf('/');
    return slash < 0 ? null : uri.substring('package:'.length, slash);
  }

  PackageEntry? _entryForPath(String normalized) {
    for (final PackageEntry e in _packages) {
      if (normalized.startsWith(e.root)) {
        return e;
      }
    }
    return null;
  }

  /// True for this scanner's own code.
  bool isSelf(String uri) {
    if (uri.startsWith('package:$selfPackage/')) {
      return true;
    }
    if (!looksLikePath(uri)) {
      return false;
    }
    final String p = normalizePath(uri);
    final String? selfLib = _selfLib;
    return selfLib != null ? p.startsWith(selfLib) : _selfPathRe.hasMatch(p);
  }

  /// True for packages that ship with the Flutter SDK.
  bool isFlutterSdk(String uri) {
    final String? name = _packageNameOf(uri);
    if (name != null) {
      return flutterSdkPackages.contains(name);
    }
    if (!looksLikePath(uri)) {
      return false;
    }
    final String p = normalizePath(uri);
    return _sdkPathRe.hasMatch(p) || p.contains('/bin/cache/pkg/sky_engine/');
  }

  /// Frames skipped when looking for whoever called into the framework:
  /// `dart:`, the Flutter SDK, test infrastructure, and this scanner.
  /// Third-party packages are NOT skipped (that is how Bloc is recognised).
  bool isSkippedCaller(String uri) {
    if (uri.startsWith('dart:') || uri.startsWith('org-dartlang-sdk:')) {
      return true;
    }
    final String? name = _packageNameOf(uri);
    if (name != null && _infraPackages.contains(name)) {
      return true;
    }
    return isSelf(uri) || isFlutterSdk(uri);
  }

  /// True when [uri] (a stack frame URI or a creation-location file) is the
  /// developer's own code.
  bool isApp(String uri) =>
      _appCache.putIfAbsent(uri, () => _computeIsApp(uri));

  /// Test hook: path fragments to treat as third-party code.
  static Set<String> debugThirdPartyPaths = <String>{};

  bool _computeIsApp(String uri) {
    if (uri.startsWith('dart:') || isSelf(uri) || isFlutterSdk(uri)) {
      return false;
    }
    if (debugThirdPartyPaths.any(uri.contains)) {
      return false;
    }
    final String? name = _packageNameOf(uri);
    if (name != null) {
      return name == appPackage || (exact && _localNames.contains(name));
    }
    if (!looksLikePath(uri)) {
      return false;
    }
    final String p = normalizePath(uri);
    if (exact) {
      final PackageEntry? entry = _entryForPath(p);
      if (entry != null) {
        return entry.local;
      }
      final String? root = _projectRoot;
      if (root != null && p.startsWith(root)) {
        return true;
      }
    }
    return !_looksThirdPartyPath(p);
  }

  /// Path heuristics for when package_config.json is not available. Pub
  /// caches live in different places per OS: ~/.pub-cache,
  /// %LOCALAPPDATA%\Pub\Cache, or a PUB_CACHE override.
  bool _looksThirdPartyPath(String p) {
    final String? pubCache = _pubCache;
    return p.contains('.pub-cache/') ||
        p.contains('/pub-cache/') ||
        p.contains('/pub/cache/') ||
        p.contains('/hosted/pub.dev/') ||
        p.contains('/hosted/pub.dartlang.org/') ||
        p.contains('/flutter/bin/cache/') ||
        p.contains('/bin/cache/pkg/') ||
        (pubCache != null && p.startsWith(pubCache)) ||
        _sdkPathRe.hasMatch(p) ||
        (p.contains('/git/') && p.contains('cache'));
  }

  /// Short, project-relative form of [uri] for display, e.g. `lib/main.dart`.
  String shortPath(String uri) {
    final String? name = _packageNameOf(uri);
    if (name != null) {
      final String rest = uri.substring('package:$name/'.length);
      final PackageEntry? entry = _byName[name];
      if (entry != null && entry.local) {
        final String? rel = _relativeToProject('${entry.libOriginal}$rest');
        if (rel != null) {
          return rel;
        }
      }
      if (name == appPackage) {
        return 'lib/$rest';
      }
      return uri;
    }
    if (!looksLikePath(uri)) {
      return uri;
    }
    final String p = normalizePath(uri, lower: false);
    final String? rel = _relativeToProject(p);
    if (rel != null) {
      return rel;
    }
    for (final String dir in const <String>[
      '/lib/',
      '/test/',
      '/integration_test/',
      '/test_driver/'
    ]) {
      final int i = p.lastIndexOf(dir);
      if (i >= 0) {
        return p.substring(i + 1);
      }
    }
    return p;
  }

  String? _relativeToProject(String path) {
    final String? root = _projectRoot;
    if (root == null || !path.toLowerCase().startsWith(root)) {
      return null;
    }
    return path.substring(root.length);
  }
}
