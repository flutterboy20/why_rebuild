/// Reads the instrumentation log lines Flutter prints when
/// `debugInstrumentationEnabled` is on.
///
/// Flutter logs `service extension method received: <name>(<params>)` before
/// running any service extension handler. DevTools' "Count widget builds"
/// calls `ext.flutter.inspector.trackRebuildDirtyWidgets`, whose handler
/// asserts that `debugOnRebuildDirtyWidget` is free. Seeing the log line first
/// lets the scanner release the hook in time.
class DevToolsToggle {
  DevToolsToggle._();

  /// The inspector extension behind "Count widget builds".
  static const String extension =
      'ext.flutter.inspector.trackRebuildDirtyWidgets';

  static const String _receivedPrefix = 'service extension method received: ';

  /// `true` / `false` when [message] is DevTools turning rebuild tracking on
  /// or off; null for any other message.
  static bool? parse(String message) {
    if (!message.startsWith(_receivedPrefix) || !message.contains(extension)) {
      return null;
    }
    if (message.contains('enabled: true')) {
      return true;
    }
    if (message.contains('enabled: false')) {
      return false;
    }
    return null;
  }

  /// True for log lines that only exist because instrumentation is on:
  /// `service extension method received: ...` and `Action "..." took ...`.
  static bool isInstrumentationLine(String message) =>
      message.startsWith(_receivedPrefix) ||
      (message.startsWith('Action "') && message.contains('" took '));
}
