/// Why a widget rebuilt.
enum CauseKind {
  /// App code called `setState` on this widget's state.
  setState,

  /// An ancestor rebuilt and handed this widget a new configuration.
  parent,

  /// An `InheritedWidget` this widget depends on notified it.
  inherited,

  /// An animation tick or a `Listenable` notification.
  listenable,

  /// A known state-management library rebuilt it (Riverpod, Bloc, ...).
  stateLibrary,

  /// Lite mode only: the element marked itself dirty, exact reason unknown.
  self,

  /// Nothing matched.
  unknown,
}

/// What made an element dirty, with a human description and an optional
/// `file:line` location.
class Trigger {
  /// Creates a trigger.
  const Trigger(this.kind, this.description, this.location);

  /// The cause kind.
  final CauseKind kind;

  /// Human readable description, e.g. `setState in HomePageState.addToCart`.
  final String description;

  /// Short `file:line`, e.g. `lib/main.dart:80`.
  final String? location;

  /// Description plus location.
  String get text =>
      location == null ? description : '$description at $location';
}

/// One rebuild of one element in the current frame.
class FrameEvent {
  /// Creates a frame event.
  const FrameEvent(this.trigger, this.rootWidget, {this.ignored = false});

  /// Why it rebuilt (for `parent` rebuilds: the trigger of the cascade root).
  final Trigger trigger;

  /// Name of the widget at the root of the rebuild cascade.
  final String rootWidget;

  /// True for rebuilds that are not app-caused (hot reload): not recorded.
  final bool ignored;
}
