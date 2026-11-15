/// Why the scanner is, or isn't, recording right now.
enum ScanState {
  /// Hooks attached; rebuilds are being recorded.
  recording,

  /// Not recording because nobody asked it to (or it was stopped).
  paused,

  /// DevTools "Count widget builds" is on. Recording resumes automatically
  /// when it is turned off.
  yieldedToDevTools,

  /// Another tool owns `debugOnRebuildDirtyWidget`. Retried every frame.
  blockedByOtherTool,

  /// Too many internal errors; the scanner detached itself to protect the app.
  disabledAfterErrors,
}

/// Scanner status, as returned by `ext.why_rebuild.status`.
class ScanStatus {
  /// Creates a status.
  const ScanStatus({
    required this.state,
    required this.mode,
    required this.framesWithRebuilds,
    required this.rebuildsRecorded,
    required this.widgetsTracked,
    this.note,
    this.errors = 0,
    this.lastError,
  });

  /// Current state.
  final ScanState state;

  /// `full` (exact causes from stack traces) or `lite` (best guesses).
  final String mode;

  /// Human note explaining the state, when relevant.
  final String? note;

  /// Frames in which at least one rebuild happened.
  final int framesWithRebuilds;

  /// App-widget rebuilds recorded.
  final int rebuildsRecorded;

  /// Distinct widget call sites tracked.
  final int widgetsTracked;

  /// Internal errors caught so far.
  final int errors;

  /// Last internal error message.
  final String? lastError;

  /// JSON form used by the service extensions.
  Map<String, Object?> toJson() => <String, Object?>{
        'state': state.name,
        'mode': mode,
        if (note != null) 'note': note,
        'framesWithRebuilds': framesWithRebuilds,
        'rebuildsRecorded': rebuildsRecorded,
        'widgetsTracked': widgetsTracked,
        if (errors > 0) 'errors': errors,
        if (lastError != null) 'lastError': lastError,
      };

  @override
  String toString() => 'ScanStatus(${toJson()})';
}

/// One widget call site in a [RebuildReport].
class RebuildSite {
  /// Creates a site summary.
  const RebuildSite({
    required this.widget,
    required this.location,
    required this.rebuilds,
    required this.wasted,
    required this.propsUnknown,
    required this.cause,
    required this.trigger,
  });

  /// Widget type name.
  final String widget;

  /// Where the app created the widget (`file:line`).
  final String location;

  /// Rebuilds recorded.
  final int rebuilds;

  /// Rebuilds with unchanged props.
  final int wasted;

  /// Parent rebuilds whose props could not be compared.
  final int propsUnknown;

  /// Most frequent cause.
  final String? cause;

  /// Most frequent trigger.
  final String? trigger;

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'widget': widget,
        'location': location,
        'rebuilds': rebuilds,
        'wasted': wasted,
        if (propsUnknown > 0) 'propsUnknown': propsUnknown,
        'cause': cause,
        'trigger': trigger,
      };

  @override
  String toString() => 'RebuildSite(${toJson()})';
}

/// The most rebuilt widgets, as returned by `ext.why_rebuild.report`.
class RebuildReport {
  /// Creates a report.
  const RebuildReport({
    required this.state,
    required this.mode,
    required this.framesWithRebuilds,
    required this.top,
    this.note,
  });

  /// Scanner state when the report was made.
  final ScanState state;

  /// `full` or `lite`.
  final String mode;

  /// Note (lite mode warning), when relevant.
  final String? note;

  /// Frames in which at least one rebuild happened.
  final int framesWithRebuilds;

  /// Most rebuilt call sites, highest first.
  final List<RebuildSite> top;

  /// Sum of [RebuildSite.rebuilds] over [top].
  int get totalRebuilds =>
      top.fold(0, (int a, RebuildSite s) => a + s.rebuilds);

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'state': state.name,
        'mode': mode,
        if (note != null) 'note': note,
        'framesWithRebuilds': framesWithRebuilds,
        'top': <Map<String, Object?>>[
          for (final RebuildSite s in top) s.toJson()
        ],
      };

  @override
  String toString() => 'RebuildReport(${toJson()})';
}

/// Details for one call site of a widget, in a [WhyReport].
class CallSite {
  /// Creates a call site.
  const CallSite({
    required this.location,
    required this.rebuilds,
    required this.wasted,
    required this.propsUnknown,
    required this.causes,
    required this.triggers,
    required this.changedDependencies,
    required this.fixHint,
  });

  /// Where the app created the widget.
  final String location;

  /// Rebuilds recorded.
  final int rebuilds;

  /// Rebuilds with unchanged props.
  final int wasted;

  /// Parent rebuilds whose props could not be compared.
  final int propsUnknown;

  /// Count per cause.
  final Map<String, int> causes;

  /// Count per trigger.
  final Map<String, int> triggers;

  /// Count per inherited widget that changed.
  final Map<String, int> changedDependencies;

  /// Suggested fix, when a rule matched.
  final String? fixHint;

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'location': location,
        'rebuilds': rebuilds,
        'wasted': wasted,
        if (propsUnknown > 0) 'propsUnknown': propsUnknown,
        'causes': causes,
        'triggers': triggers,
        if (changedDependencies.isNotEmpty)
          'changedDependencies': changedDependencies,
        'fixHint': fixHint,
      };

  @override
  String toString() => 'CallSite(${toJson()})';
}

/// Why one widget rebuilt, as returned by `ext.why_rebuild.why`.
class WhyReport {
  /// Creates a report.
  const WhyReport({
    required this.widget,
    required this.mode,
    required this.callSites,
    this.note,
  });

  /// The widget name asked about.
  final String widget;

  /// `full` or `lite`.
  final String mode;

  /// Note (lite mode warning), when relevant.
  final String? note;

  /// One entry per place the app creates this widget, most rebuilt first.
  final List<CallSite> callSites;

  /// Total rebuilds over all call sites.
  int get rebuilds => callSites.fold(0, (int a, CallSite c) => a + c.rebuilds);

  /// Total wasted rebuilds over all call sites.
  int get wasted => callSites.fold(0, (int a, CallSite c) => a + c.wasted);

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'widget': widget,
        'mode': mode,
        if (note != null) 'note': note,
        'callSites': <Map<String, Object?>>[
          for (final CallSite c in callSites) c.toJson()
        ],
      };

  /// Multi-line, human readable explanation (used in test failure messages).
  String describe() {
    final StringBuffer b = StringBuffer();
    if (callSites.isEmpty) {
      b.writeln('$widget: no rebuilds recorded.');
    }
    for (final CallSite c in callSites) {
      b.writeln(
          '$widget (${c.location}): ${c.rebuilds} rebuilds, ${c.wasted} wasted'
          '${c.propsUnknown > 0 ? ', ${c.propsUnknown} with unknown props' : ''}');
      for (final MapEntry<String, int> e in c.causes.entries) {
        b.writeln('  cause:   ${e.key} x${e.value}');
      }
      for (final MapEntry<String, int> e in c.triggers.entries) {
        b.writeln('  trigger: ${e.key} x${e.value}');
      }
      for (final MapEntry<String, int> e in c.changedDependencies.entries) {
        b.writeln('  changed: ${e.key} x${e.value}');
      }
      if (c.fixHint != null) {
        b.writeln('  fix:     ${c.fixHint}');
      }
    }
    if (note != null) {
      b.writeln('note: $note');
    }
    return b.toString().trimRight();
  }

  @override
  String toString() => describe();
}

/// Widgets with wasted rebuilds, as returned by `ext.why_rebuild.why` without
/// a `widget` argument.
class WastedReport {
  /// Creates a report.
  const WastedReport({required this.mode, required this.widgets, this.note});

  /// `full` or `lite`.
  final String mode;

  /// Note for the reader.
  final String? note;

  /// Call sites with at least one wasted rebuild, most wasted first.
  final List<RebuildSite> widgets;

  /// JSON form.
  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode,
        if (note != null) 'note': note,
        'wastedWidgets': <Map<String, Object?>>[
          for (final RebuildSite s in widgets) s.toJson()
        ],
      };

  @override
  String toString() => 'WastedReport(${toJson()})';
}
