import 'package:flutter/widgets.dart';

import '../classify/classifier.dart';
import '../classify/friendly_names.dart';
import '../locate/creation_location.dart';
import '../model/cause.dart';
import '../model/stats.dart';
import '../wasted/props_signature.dart';
import 'schedule_stacks.dart';

/// Turns `debugOnRebuildDirtyWidget` callbacks into recorded stats.
class RebuildRecorder {
  /// Creates a recorder.
  RebuildRecorder({
    required this.locations,
    required this.stacks,
    required this.classifier,
    required this.stats,
  });

  /// Widget creation locations.
  final LocationCache locations;

  /// Stacks captured from `debugPrintScheduleBuildForStacks`.
  final ScheduleStackCollector stacks;

  /// Cause rules.
  final Classifier classifier;

  /// Where results go.
  final StatsStore stats;

  /// Full mode when true; lite mode (no stacks) when false.
  bool useStacks = true;

  /// Test hook (via `WhyRebuild.debugDropStacks`): pretend stack capture
  /// stopped working.
  bool debugDropStacks = false;

  /// Dirty, already-built elements whose stack was found / missing in a row.
  int stackHits = 0;

  /// See [stackHits].
  int consecutiveStackMisses = 0;

  /// What rebuilt this frame, in build order.
  final Map<Element, FrameEvent> frameEvents = <Element, FrameEvent>{};

  Expando<String> _lastSig = Expando<String>('why_rebuild.sig');
  Expando<bool> _seen = Expando<bool>('why_rebuild.seen');

  /// Forgets per-element memory (props signatures, first-build tracking).
  void forgetElements() {
    _lastSig = Expando<String>('why_rebuild.sig');
    _seen = Expando<bool>('why_rebuild.seen');
    locations.clear();
  }

  /// Handles one rebuilt element.
  void onRebuild(Element element) {
    final Widget widget = element.widget;
    final WidgetLocation loc = locations.of(element);

    // Don't trust `builtOnce`: the framework only sets it when
    // debugPrintRebuildDirtyWidgets is also on.
    final bool firstBuild = _isFirstBuild(element);
    _seen[element] = true;

    String? sig;
    String? previousSig;
    if (loc.local) {
      sig = propsSignature(widget);
      previousSig = _lastSig[element];
      _lastSig[element] = sig ?? '';
    }

    final bool dirty = element.dirty;
    final FrameEvent event;
    List<InheritedElement> changedDeps = const <InheritedElement>[];
    if (dirty) {
      changedDeps = _changedDependencies(element);
      final Classification c = _classify(element, loc, changedDeps, firstBuild);
      event =
          FrameEvent(c.trigger, _rootName(element, loc), ignored: c.ignored);
    } else {
      final FrameEvent? root = _nearestRebuiltAncestor(element);
      event = FrameEvent(
        Trigger(
            CauseKind.parent,
            root?.trigger.description ?? 'unknown ancestor',
            root?.trigger.location),
        root?.rootWidget ?? 'unknown',
        ignored: root?.ignored ?? false,
      );
    }
    frameEvents[element] = event;

    if (firstBuild || !loc.local || event.ignored) {
      return;
    }

    bool? propsChanged;
    bool propsCompared = true;
    if (!dirty) {
      if (sig != null && previousSig == null) {
        // Built before recording started: nothing to compare against yet.
        propsCompared = false;
      }
      propsChanged = (sig == null || sig.isEmpty) ? null : previousSig != sig;
    }
    stats.record(
      widget: widget.runtimeType.toString(),
      location: loc.short!,
      event: event,
      dirty: dirty,
      propsChanged: propsChanged,
      propsCompared: propsCompared,
      changedDeps: <String>[
        for (final InheritedElement d in changedDeps)
          friendlyType(d.widget.runtimeType.toString()),
      ],
    );
  }

  Classification _classify(Element element, WidgetLocation loc,
      List<InheritedElement> changedDeps, bool firstBuild) {
    List<String>? stack;
    // A first build has no markNeedsBuild stack: don't look one up.
    if (useStacks && !firstBuild) {
      stack = debugDropStacks ? null : _stackOf(element);
      {
        if (stack == null) {
          consecutiveStackMisses++;
        } else {
          stackHits++;
          consecutiveStackMisses = 0;
        }
      }
    }
    if (stack != null) {
      return classifier.withStack(
        stack: stack,
        element: element,
        loc: loc,
        changedDeps: changedDeps,
        lookup: _lookup,
      );
    }
    return classifier.withoutStack(
      element: element,
      loc: loc,
      changedDeps: changedDeps,
      lookup: _lookup,
    );
  }

  /// True on an element's very first build. A component element has no
  /// child until then, which also works for elements mounted while the
  /// scanner was not recording.
  bool _isFirstBuild(Element element) {
    if (element is ComponentElement) {
      bool hasChild = false;
      element.visitChildren((_) => hasChild = true);
      return !hasChild;
    }
    return _seen[element] == null;
  }

  /// The stack is keyed by `element.toString()`, which is what Flutter
  /// prints in the `scheduleBuildFor()` label.
  List<String>? _stackOf(Element element) {
    if (stacks.stacks.isEmpty) {
      return null;
    }
    try {
      return stacks.stackFor(element.toString());
    } catch (_) {
      return null; // toString runs app debugFillProperties, which may throw.
    }
  }

  FrameEvent? _lookup(Element element) => frameEvents[element];

  /// The cascade root's name. Framework-internal roots (a route's
  /// AnimatedBuilder, an InkWell's state) are named with the nearest app
  /// ancestor so the developer knows where to look.
  String _rootName(Element element, WidgetLocation loc) {
    final String name = friendlyType(element.widget.runtimeType.toString());
    if (loc.local) {
      return name;
    }
    String? app;
    element.visitAncestorElements((Element a) {
      if (locations.of(a).local) {
        app = friendlyType(a.widget.runtimeType.toString());
        return false;
      }
      return true;
    });
    return app == null ? name : '$name under $app';
  }

  FrameEvent? _nearestRebuiltAncestor(Element element) {
    FrameEvent? found;
    element.visitAncestorElements((Element ancestor) {
      found = frameEvents[ancestor];
      return found == null;
    });
    return found;
  }

  /// An InheritedElement that rebuilt earlier in this frame and that
  /// [element] depends on is what changed. Dependents always build after
  /// their inherited ancestor, so no history is needed.
  List<InheritedElement> _changedDependencies(Element element) {
    if (frameEvents.isEmpty) {
      return const <InheritedElement>[];
    }
    // Element diagnostics are the only public view of `dependencies`. They
    // also run the widget's debugFillProperties, which may be broken in app
    // code: then we just don't know.
    final List<DiagnosticsNode> props;
    try {
      props = element.toDiagnosticsNode().getProperties();
    } catch (_) {
      return const <InheritedElement>[];
    }
    for (final DiagnosticsNode p in props) {
      final Object? value = p.value;
      if (p.name == 'dependencies' && value is Set<InheritedElement>) {
        return <InheritedElement>[
          for (final InheritedElement d in value)
            if (frameEvents.containsKey(d)) d,
        ];
      }
    }
    return const <InheritedElement>[];
  }

  /// Clears per-frame data. Returns true when anything rebuilt this frame.
  bool endFrame() {
    final bool any = frameEvents.isNotEmpty;
    frameEvents.clear();
    stacks.clear();
    return any;
  }
}
