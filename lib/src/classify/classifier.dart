import 'package:flutter/widgets.dart';

import '../capture/stack_frames.dart';
import '../locate/app_package.dart';
import '../locate/creation_location.dart';
import '../model/cause.dart';
import 'friendly_names.dart';
import 'libraries.dart';

/// Looks up what happened to an element earlier in the current frame.
typedef FrameEventLookup = FrameEvent? Function(Element element);

/// Result of classifying a dirty element: a trigger, or "ignore" (hot reload).
class Classification {
  const Classification._(this.trigger, this.ignored);

  /// A real cause.
  const Classification.of(Trigger trigger) : this._(trigger, false);

  /// Not an app-caused rebuild (hot reload marks every element dirty).
  static const Classification ignore =
      Classification._(Trigger(CauseKind.unknown, 'hot reload', null), true);

  /// The trigger.
  final Trigger trigger;

  /// True when the rebuild should not be recorded.
  final bool ignored;
}

/// Turns a dirty element (+ the stack of its `markNeedsBuild`, when captured)
/// into a [Trigger]. Implements the rules of the design spec, section 7.
class Classifier {
  /// Creates a classifier.
  Classifier(this.origin);

  /// Decides app vs third-party code.
  final CodeOrigin origin;

  static const String _fw = 'widgets/framework.dart';

  /// Full mode: classify from the `markNeedsBuild` stack.
  Classification withStack({
    required List<String> stack,
    required Element element,
    required WidgetLocation loc,
    required List<InheritedElement> changedDeps,
    required FrameEventLookup lookup,
  }) {
    final String name = friendlyType(element.widget.runtimeType.toString());
    final List<StackFrameInfo> frames = parseStack(stack, origin);
    bool has(String method, String file) =>
        frames.any((StackFrameInfo f) => f.matches(method, file));
    StackFrameInfo? appFrame;
    StackFrameInfo? caller;
    for (final StackFrameInfo f in frames) {
      if (appFrame == null && f.isApp) {
        appFrame = f;
      }
      if (caller == null && !origin.isSkippedCaller(f.uri)) {
        caller = f;
      }
    }

    // Hot reload marks every element dirty; not an app cause.
    if (has('reassemble', _fw) ||
        has('performReassemble', 'foundation/binding.dart')) {
      return Classification.ignore;
    }

    // 1. An InheritedWidget notified its dependents.
    if (has('notifyClients', _fw) ||
        has('didChangeDependencies', _fw) ||
        has('notifyDependent', _fw)) {
      return Classification.of(Trigger(
        CauseKind.inherited,
        changedDeps.isEmpty
            ? 'an inherited widget changed'
            : describeDeps(changedDeps, lookup),
        appFrame?.location,
      ));
    }

    // 2. A ticker is driven by the engine, so any "app frame" on its stack is
    //    just whoever pumped the frame. Point at the animated widget instead.
    if (has('_tick', 'scheduler/ticker.dart')) {
      return Classification.of(
          Trigger(CauseKind.listenable, 'animation tick in $name', loc.short));
    }

    // 3. A state library called markNeedsBuild directly (Riverpod, MobX, ...).
    final String? library = stateLibraryOf(frames);
    if (library != null && !has('setState', _fw)) {
      return Classification.of(Trigger(
        CauseKind.stateLibrary,
        appFrame == null
            ? '$library notified $name'
            : '$library notified $name after ${appFrame.method}',
        appFrame?.location ?? loc.short,
      ));
    }

    // 4. A Listenable notified (AnimatedBuilder, ListenableBuilder,
    //    ValueListenableBuilder, ChangeNotifier). ChangeNotifier lives in
    //    foundation/change_notifier.dart up to Flutter 3.47 and in
    //    package:listen from 3.50.
    if (has('_handleChange', 'widgets/transitions.dart') ||
        has('notifyListeners', 'animation/listener_helpers.dart') ||
        has('notifyListeners', 'foundation/change_notifier.dart') ||
        has('notifyListeners', 'package:listen/')) {
      return Classification.of(Trigger(
        CauseKind.listenable,
        appFrame == null
            ? 'listenable notified $name'
            : 'listenable notified by ${appFrame.method}',
        appFrame?.location ?? loc.short,
      ));
    }

    // 5. setState.
    if (has('setState', _fw)) {
      // StreamBuilder/FutureBuilder setState themselves when a snapshot
      // arrives. Async stacks may show app frames from before the gap; they
      // are not the cause.
      final Widget widget = element.widget;
      if ((widget is StreamBuilderBase || widget is FutureBuilder) &&
          frames.any(
              (StackFrameInfo f) => f.uri.contains('widgets/async.dart'))) {
        return Classification.of(
            Trigger(CauseKind.listenable, 'new snapshot in $name', loc.short));
      }
      if (caller != null && !caller.isApp) {
        // setState inside a library widget (e.g. BlocBuilder reacting to a
        // stream). The useful location is where the app created the widget.
        return Classification.of(Trigger(CauseKind.stateLibrary,
            'setState in $name (${caller.package})', loc.short));
      }
      if (caller == null) {
        // Only framework code on the stack: a framework widget updating
        // itself.
        return Classification.of(
            Trigger(CauseKind.setState, 'setState in $name', loc.short));
      }
      return Classification.of(Trigger(
          CauseKind.setState, 'setState in ${caller.method}', caller.location));
    }

    // 6. Nothing matched.
    return Classification.of(Trigger(
        CauseKind.unknown, appFrame?.method ?? 'unknown', appFrame?.location));
  }

  /// Lite mode (no stack): best guesses from the element itself.
  Classification withoutStack({
    required Element element,
    required WidgetLocation loc,
    required List<InheritedElement> changedDeps,
    required FrameEventLookup lookup,
  }) {
    if (changedDeps.isNotEmpty) {
      return Classification.of(Trigger(
          CauseKind.inherited, describeDeps(changedDeps, lookup), null));
    }
    final String name = friendlyType(element.widget.runtimeType.toString());
    if (element.widget is AnimatedWidget) {
      return Classification.of(Trigger(
          CauseKind.listenable, 'animation or listenable in $name', loc.short));
    }
    if (element is StatefulElement) {
      return Classification.of(Trigger(CauseKind.self,
          'state changed in $name (setState or a listener)', loc.short));
    }
    return Classification.of(
        Trigger(CauseKind.self, '$name marked itself dirty', loc.short));
  }

  /// e.g. `MediaQuery changed`, or `Provider<CartModel> changed (...)` when
  /// the inherited widget's own rebuild has a known cause this frame.
  String describeDeps(List<InheritedElement> deps, FrameEventLookup lookup) {
    return deps.map((InheritedElement d) {
      final String depName = friendlyType(d.widget.runtimeType.toString());
      final Trigger? why = lookup(d)?.trigger;
      if (why == null ||
          why.kind == CauseKind.parent ||
          why.kind == CauseKind.unknown ||
          why.kind == CauseKind.self) {
        return '$depName changed';
      }
      return '$depName changed (${why.text})';
    }).join(', ');
  }
}
