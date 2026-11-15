/// Collects the stack trace Flutter prints for every `markNeedsBuild` when
/// `debugPrintScheduleBuildForStacks` is on, by reading `debugPrint` output.
///
/// `debugPrintStack` prints the label and the stack as two consecutive
/// `debugPrint` calls:
///
///     scheduleBuildFor() called for HomePage(state: HomePageState#1a2b3)
///     #0 State.setState (package:flutter/src/widgets/framework.dart:1221:5)
///     ...
class ScheduleStackCollector {
  static const String _schedulePrefix = 'scheduleBuildFor() called for ';
  static const String _alreadyInList = ' (ALREADY IN LIST)';
  static const String _resortPrefix = 'BuildOwner.scheduleBuildFor() called; ';
  static const String _dirtyListPrefix =
      "...the build scope's dirty list is now";

  /// Stack lines per element description (`element.toString()`), for the
  /// current frame.
  final Map<String, List<String>> stacks = <String, List<String>>{};

  String? _pendingLabel;
  bool _discardNext = false;

  /// Labels seen since the last [resetCounters].
  int labelsSeen = 0;

  /// Handles one `debugPrint` message. Returns true when the message belonged
  /// to stack capture. [active] is false when someone else turned the flag
  /// on: then nothing is consumed.
  bool handle(String message, {required bool active}) {
    if (message.startsWith(_schedulePrefix)) {
      if (!active) {
        return false;
      }
      String label = message.substring(_schedulePrefix.length);
      if (label.endsWith(_alreadyInList)) {
        label = label.substring(0, label.length - _alreadyInList.length);
      }
      _pendingLabel = label;
      _discardNext = false;
      labelsSeen++;
      return true;
    }
    if (message.startsWith(_resortPrefix)) {
      if (!active) {
        return false;
      }
      _pendingLabel = null;
      _discardNext = true; // Its stack follows; not needed.
      return true;
    }
    final String? label = _pendingLabel;
    if (label != null) {
      stacks[label] = message.split('\n');
      _pendingLabel = null;
      return true;
    }
    if (_discardNext) {
      _discardNext = false;
      return true;
    }
    if (message.startsWith(_dirtyListPrefix)) {
      return active;
    }
    return false;
  }

  /// Stack for [element]'s description, if one was captured this frame.
  List<String>? stackFor(String elementDescription) =>
      stacks[elementDescription];

  /// Clears per-frame data.
  void clear() {
    stacks.clear();
    _pendingLabel = null;
    _discardNext = false;
  }

  /// Resets [labelsSeen].
  void resetCounters() {
    labelsSeen = 0;
  }
}
