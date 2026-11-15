import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'capture/devtools_yield.dart';
import 'capture/rebuild_hook.dart';
import 'capture/schedule_stacks.dart';
import 'classify/classifier.dart';
import 'extensions/service_extensions.dart';
import 'hints/fix_hints.dart';
import 'locate/app_package.dart';
import 'locate/creation_location.dart';
import 'model/report.dart';
import 'model/stats.dart';

/// Records **why** each app widget rebuilt (which `setState`, which
/// `InheritedWidget`, which animation or state library), whether the rebuild
/// was wasted, and how to fix it.
///
/// Debug builds only: [install] does nothing in profile and release builds
/// (the code is tree-shaken) and nothing on web.
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   WhyRebuild.instance.install();
///   runApp(const MyApp());
/// }
/// ```
///
/// Results are available through this API and through the
/// `ext.why_rebuild.*` VM service extensions (for DevTools, the Dart MCP
/// server, and AI agents).
class WhyRebuild {
  WhyRebuild._();

  /// The single scanner instance.
  static final WhyRebuild instance = WhyRebuild._();

  /// After this many internal errors the scanner detaches itself.
  static const int maxErrors = 20;

  /// Dirty elements in a row without a captured stack before falling back to
  /// lite mode (stack capture probably broke on this Flutter version).
  static const int stackMissesBeforeLite = 50;

  static bool _webWarned = false;

  bool _installed = false;
  bool _extensionsRegistered = false;
  bool _frameCallbackAdded = false;

  // Intent and facts.
  bool _wantRecording = false;
  bool _yieldedToDevTools = false;
  bool _wantStacks = true;
  bool _fellBackToLite = false;
  int _errors = 0;
  String? _lastError;
  late final Set<String> _warned = <String>{};

  // Saved framework state, restored on uninstall.
  DebugPrintCallback? _originalDebugPrint;
  bool _originalInstrumentation = false;
  bool _originalScheduleStacks = false;

  late final StatsStore _stats = StatsStore();
  late final ScheduleStackCollector _stacks = ScheduleStackCollector();
  CodeOrigin? _origin;
  RebuildRecorder? _recorder;

  // ---------------------------------------------------------------------------
  // Lifecycle

  /// Starts the scanner. Call once in `main()`.
  ///
  /// Does nothing outside debug mode or on web (prints one warning on web).
  /// Calling it again while installed does nothing, so hot reload and hot
  /// restart are safe.
  ///
  /// * [appPackage]: your app's package name. Detected automatically from
  ///   package_config.json or the caller's stack when omitted.
  /// * [record]: start recording right away (default). When false, call
  ///   [startRecording] or `ext.why_rebuild.record` later.
  /// * [captureStacks]: false forces lite mode (no stack traces; causes are
  ///   guesses). Leave it null.
  void install({String? appPackage, bool record = true, bool? captureStacks}) {
    if (!kDebugMode) {
      return;
    }
    if (kIsWeb) {
      if (!_webWarned) {
        _webWarned = true;
        debugPrint('why_rebuild: web is not supported yet; doing nothing.');
      }
      return;
    }
    if (_installed) {
      return;
    }
    WidgetsFlutterBinding.ensureInitialized();
    _installed = true;
    _wantStacks = captureStacks ?? true;
    _fellBackToLite = false;
    _errors = 0;
    _lastError = null;
    _yieldedToDevTools = false;

    final CodeOrigin origin = CodeOrigin.detect(
      appPackage: appPackage,
      stack: StackTrace.current.toString(),
    );
    _origin = origin;
    _recorder = RebuildRecorder(
      locations: LocationCache(origin),
      stacks: _stacks,
      classifier: Classifier(origin),
      stats: _stats,
    )..useStacks = _wantStacks;

    _originalDebugPrint = debugPrint;
    debugPrint = _interceptDebugPrint;
    _originalInstrumentation = debugInstrumentationEnabled;
    debugInstrumentationEnabled = true;
    _originalScheduleStacks = debugPrintScheduleBuildForStacks;

    if (!_frameCallbackAdded) {
      // Persistent callbacks cannot be removed; it checks _installed.
      _frameCallbackAdded = true;
      SchedulerBinding.instance.addPersistentFrameCallback((_) => _endFrame());
    }
    if (!_extensionsRegistered) {
      _extensionsRegistered = true;
      registerServiceExtensions(this);
    }
    _wantRecording = record;
    _sync();
  }

  /// Stops the scanner and restores every framework debug global it changed
  /// (`debugPrint`, `debugInstrumentationEnabled`,
  /// `debugPrintScheduleBuildForStacks`, `debugOnRebuildDirtyWidget`).
  void uninstall() {
    if (!_installed) {
      return;
    }
    _wantRecording = false;
    _sync();
    if (debugPrint == _interceptDebugPrint && _originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
    }
    debugInstrumentationEnabled = _originalInstrumentation;
    debugPrintScheduleBuildForStacks = _originalScheduleStacks;
    _installed = false;
    _yieldedToDevTools = false;
    _recorder?.frameEvents.clear();
    _stacks.clear();
  }

  /// True between [install] and [uninstall].
  bool get isInstalled => _installed;

  /// Starts (or resumes) recording.
  void startRecording() {
    _wantRecording = true;
    _sync();
  }

  /// Stops recording. Recorded data is kept.
  void stopRecording() {
    _wantRecording = false;
    _sync();
  }

  /// Clears recorded data.
  void reset() {
    _stats.clear();
  }

  bool get _hookIsOurs => debugOnRebuildDirtyWidget == _onRebuild;

  /// Why the scanner is, or isn't, recording.
  ScanState get state {
    if (_errors >= maxErrors) {
      return ScanState.disabledAfterErrors;
    }
    if (_hookIsOurs) {
      return ScanState.recording;
    }
    if (_yieldedToDevTools) {
      return ScanState.yieldedToDevTools;
    }
    if (_installed && _wantRecording && debugOnRebuildDirtyWidget != null) {
      return ScanState.blockedByOtherTool;
    }
    return ScanState.paused;
  }

  /// `full`: causes come from stack traces (exact). `lite`: no stacks;
  /// causes are inferred and can be wrong.
  String get mode => _useStacks ? 'full' : 'lite';

  bool get _useStacks => _wantStacks && !_fellBackToLite;

  /// The app package in use (detected or given), e.g. `my_app`.
  String? get appPackage => _origin?.appPackage;

  /// Attaches or detaches the framework hooks to match intent. The only
  /// place that does so. Always checks the real hook value, because DevTools
  /// can change it behind our back.
  void _sync() {
    final bool shouldAttach = _installed &&
        _wantRecording &&
        !_yieldedToDevTools &&
        _errors < maxErrors;
    if (shouldAttach && !_hookIsOurs && debugOnRebuildDirtyWidget == null) {
      debugOnRebuildDirtyWidget = _onRebuild;
      debugPrintScheduleBuildForStacks = _useStacks || _originalScheduleStacks;
      _recorder?.consecutiveStackMisses = 0;
    } else if (!shouldAttach && _hookIsOurs) {
      debugOnRebuildDirtyWidget = null;
      _recorder?.frameEvents.clear();
      _stacks.clear();
    }
    if (!_hookIsOurs) {
      debugPrintScheduleBuildForStacks = _originalScheduleStacks;
    }
    final ScanState s = state;
    if (s == ScanState.blockedByOtherTool) {
      _warnOnce('blocked',
          'another tool owns debugOnRebuildDirtyWidget; not recording until it lets go.');
    } else if (s == ScanState.disabledAfterErrors) {
      _warnOnce('errors',
          'disabled itself after $maxErrors internal errors (last: $_lastError). Your app is unaffected.');
    }
  }

  /// Test hook: forget which warnings were already printed.
  @visibleForTesting
  void debugResetWarnings() => _warned.clear();

  void _warnOnce(String key, String message) {
    if (_warned.add(key)) {
      (_originalDebugPrint ?? debugPrint)('why_rebuild: $message');
    }
  }

  void _fail(Object error) {
    _errors++;
    _lastError = '$error';
    if (_errors >= maxErrors) {
      _sync(); // Detach rather than risk breaking the app's builds.
    }
  }

  // ---------------------------------------------------------------------------
  // debugPrint interception

  void _interceptDebugPrint(String? message, {int? wrapWidth}) {
    if (message != null) {
      try {
        if (_handleMessage(message)) {
          return;
        }
      } catch (e) {
        _fail(e);
      }
    }
    final DebugPrintCallback original =
        _originalDebugPrint ?? debugPrintThrottled;
    original(message, wrapWidth: wrapWidth);
  }

  /// Returns true when the message was ours to swallow.
  bool _handleMessage(String message) {
    if (_stacks.handle(message, active: _hookIsOurs && _useStacks)) {
      // The developer had debugPrintScheduleBuildForStacks on themselves:
      // read it, but let it print.
      return !_originalScheduleStacks;
    }
    final bool? devTools = DevToolsToggle.parse(message);
    if (devTools != null) {
      _onDevToolsToggle(devTools);
    }
    if (DevToolsToggle.isInstrumentationLine(message)) {
      return !_originalInstrumentation; // Hide only logs we caused.
    }
    return false;
  }

  /// DevTools "Count widget builds" calls the inspector's
  /// trackRebuildDirtyWidgets extension. Flutter logs the call before running
  /// the handler, so we release the hook in time for the inspector's
  /// `assert(debugOnRebuildDirtyWidget == null)`.
  void _onDevToolsToggle(bool enabled) {
    if (enabled) {
      _yieldedToDevTools = true;
      _sync();
    } else {
      _yieldedToDevTools = false;
      // The inspector clears the hook right after this log line; re-attach
      // after it (and at every frame end).
      Timer(const Duration(milliseconds: 100), _safeSync);
    }
  }

  void _safeSync() {
    try {
      _sync();
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Capture

  /// Test hook: pretend stack capture stopped working (R8).
  @visibleForTesting
  set debugDropStacks(bool value) => _recorder?.debugDropStacks = value;

  /// Test hook: throw inside the rebuild hook (R2).
  @visibleForTesting
  bool debugThrowInCapture = false;

  void _onRebuild(Element element, bool builtOnce) {
    try {
      if (debugThrowInCapture) {
        throw StateError('debugThrowInCapture');
      }
      final RebuildRecorder? recorder = _recorder;
      if (recorder == null) {
        return;
      }
      recorder.onRebuild(element);
      if (recorder.useStacks &&
          recorder.consecutiveStackMisses >= stackMissesBeforeLite) {
        _fallBackToLite();
      }
    } catch (e) {
      _fail(e);
    }
  }

  void _fallBackToLite() {
    _fellBackToLite = true;
    _recorder?.useStacks = false;
    if (_hookIsOurs) {
      debugPrintScheduleBuildForStacks = _originalScheduleStacks;
    }
    _warnOnce(
        'lite',
        'could not read rebuild stack traces on this Flutter version; switched to '
            'lite mode (causes are best guesses).');
  }

  void _endFrame() {
    if (!_installed) {
      return;
    }
    try {
      if (_recorder?.endFrame() ?? false) {
        _stats.frames++;
      }
      if (_wantRecording && !_hookIsOurs) {
        _sync(); // Re-attach if DevTools or another tool released the hook.
      }
    } catch (e) {
      _fail(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Queries

  String? get _modeNote {
    if (_fellBackToLite) {
      return 'Lite mode: stack capture stopped working on this Flutter version, '
          'so causes are best guesses. Do not trust them blindly.';
    }
    if (!_wantStacks) {
      return 'Lite mode (no stack traces): causes are best guesses. Do not trust '
          'them blindly.';
    }
    return null;
  }

  /// Current status.
  ScanStatus status() {
    final ScanState s = state;
    final String? note = switch (s) {
      ScanState.yieldedToDevTools =>
        'DevTools "Count widget builds" is on. Recording '
            'resumes automatically when it is turned off.',
      ScanState.blockedByOtherTool =>
        'Another tool owns the rebuild hook (debugOnRebuildDirtyWidget). Turn it off to resume.',
      ScanState.disabledAfterErrors =>
        'Disabled after $maxErrors internal errors to protect the app. Restart the app to retry.',
      ScanState.paused when !_installed =>
        'Not installed. Call WhyRebuild.instance.install() in main().',
      _ => _modeNote,
    };
    return ScanStatus(
      state: s,
      mode: mode,
      note: note,
      framesWithRebuilds: _stats.frames,
      rebuildsRecorded: _stats.events,
      widgetsTracked: _stats.length,
      errors: _errors,
      lastError: _lastError,
    );
  }

  RebuildSite _site(CallSiteStats s) => RebuildSite(
        widget: s.widget,
        location: s.location,
        rebuilds: s.rebuilds,
        wasted: s.wasted,
        propsUnknown: s.propsUnknown,
        cause: s.topCause,
        trigger: s.topTrigger,
      );

  /// The [limit] most rebuilt widget call sites.
  RebuildReport report({int limit = 10}) => RebuildReport(
        state: state,
        mode: mode,
        note: _modeNote,
        framesWithRebuilds: _stats.frames,
        top: <RebuildSite>[
          for (final CallSiteStats s in _stats.sorted().take(limit)) _site(s)
        ],
      );

  /// Why [widget] rebuilt. Matches `BlocBuilder` and `BlocBuilder<A, B>`.
  WhyReport why(String widget) => WhyReport(
        widget: widget,
        mode: mode,
        note: _modeNote,
        callSites: <CallSite>[
          for (final CallSiteStats s in _stats.sitesOf(widget))
            CallSite(
              location: s.location,
              rebuilds: s.rebuilds,
              wasted: s.wasted,
              propsUnknown: s.propsUnknown,
              causes: Map<String, int>.of(s.causes),
              triggers: Map<String, int>.of(s.triggers),
              changedDependencies: Map<String, int>.of(s.changedDependencies),
              fixHint: fixHint(s),
            ),
        ],
      );

  /// Call sites with wasted rebuilds, most wasted first. A good place to
  /// start when you don't know widget names yet.
  WastedReport wasted({int limit = 10}) {
    final List<CallSiteStats> sites = _stats
        .sorted()
        .where((CallSiteStats s) => s.wasted > 0)
        .toList()
      ..sort(
          (CallSiteStats a, CallSiteStats b) => b.wasted.compareTo(a.wasted));
    return WastedReport(
      mode: mode,
      note: sites.isEmpty
          ? 'No wasted rebuilds recorded. Record while reproducing the slow flow, then ask again.'
          : 'Ask why(widget) for causes and a fix hint.',
      widgets: <RebuildSite>[
        for (final CallSiteStats s in sites.take(limit)) _site(s)
      ],
    );
  }
}
