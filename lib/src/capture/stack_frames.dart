import '../locate/app_package.dart';

/// One parsed Dart VM stack frame.
class StackFrameInfo {
  /// Creates a frame.
  const StackFrameInfo({
    required this.method,
    required this.uri,
    required this.location,
    required this.isApp,
  });

  /// e.g. `HomePageState.addToCart`, `State.setState`.
  final String method;

  /// e.g. `package:app/main.dart`, `file:///.../test/x_test.dart`.
  final String uri;

  /// Short `file:line`, e.g. `lib/main.dart:58`.
  final String location;

  /// True when the frame is app code.
  final bool isApp;

  /// `package:name` of the frame, or the URI itself for non-package URIs.
  String get package {
    final RegExpMatch? m = RegExp(r'^package:([^/]+)/').firstMatch(uri);
    return m == null ? uri : 'package:${m.group(1)}';
  }

  /// True when [method] is [name] or ends with `.name` and the URI contains
  /// [file]. Matching by method name + file keeps rules independent of the
  /// exact frame text.
  bool matches(String name, String file) =>
      (method == name || method.endsWith('.$name')) && uri.contains(file);
}

// "#3      _HomePageState.addToCart (package:app/main.dart:58:5)"
// "#3      _HomePageState.addToCart.<anonymous closure> (file:///C:/x/y.dart:58)"
final RegExp _vmFrame = RegExp(r'^#\d+\s+(.+?) \((.+?):(\d+)(?::\d+)?\)$');

/// Parses Dart VM stack lines; lines in other formats are skipped.
List<StackFrameInfo> parseStack(Iterable<String> lines, CodeOrigin origin) {
  final List<StackFrameInfo> frames = <StackFrameInfo>[];
  for (final String raw in lines) {
    final RegExpMatch? m = _vmFrame.firstMatch(raw.trim());
    if (m == null) {
      continue;
    }
    final String uri = m.group(2)!;
    frames.add(StackFrameInfo(
      method: m.group(1)!.replaceAll('.<anonymous closure>', ''),
      uri: uri,
      location: '${origin.shortPath(uri)}:${m.group(3)}',
      isApp: origin.isApp(uri),
    ));
  }
  return frames;
}
