import 'cause.dart';

/// At most this many distinct causes/triggers are kept per call site; the
/// rest are counted under `(other)` to keep responses small.
const int maxDistinctKeys = 8;

/// Aggregated stats for one widget call site (widget type + location).
class CallSiteStats {
  /// Creates empty stats.
  CallSiteStats(this.widget, this.location);

  /// Widget type name, e.g. `BlocBuilder<CounterCubit, int>`.
  final String widget;

  /// Where the app created the widget, e.g. `lib/main.dart:153`.
  final String location;

  /// Rebuilds recorded (first builds are not counted).
  int rebuilds = 0;

  /// Parent rebuilds where the widget's diagnostic properties did not change.
  int wasted = 0;

  /// Parent rebuilds where props could not be compared (no
  /// `debugFillProperties`).
  int propsUnknown = 0;

  /// Count per cause, e.g. `setState`, `parent rebuilt (HomePage)`.
  final Map<String, int> causes = <String, int>{};

  /// Count per trigger text.
  final Map<String, int> triggers = <String, int>{};

  /// Count per inherited widget that changed.
  final Map<String, int> changedDependencies = <String, int>{};

  /// Count per trigger kind, used by fix hints.
  final Map<CauseKind, int> kinds = <CauseKind, int>{};

  /// Most frequent cause.
  String? get topCause => topKey(causes);

  /// Most frequent trigger.
  String? get topTrigger => topKey(triggers);

  /// Number of rebuilds caused by an ancestor.
  int get parentRebuilds => causes.entries
      .where((MapEntry<String, int> e) => e.key.startsWith('parent'))
      .fold(0, (int a, MapEntry<String, int> e) => a + e.value);
}

/// Adds one to [key] in [map], folding into `(other)` once [maxDistinctKeys]
/// distinct keys exist.
void bump(Map<String, int> map, String key) {
  if (map.containsKey(key) || map.length < maxDistinctKeys) {
    map[key] = (map[key] ?? 0) + 1;
  } else {
    map['(other)'] = (map['(other)'] ?? 0) + 1;
  }
}

/// The key with the highest count, or null when [map] is empty.
String? topKey(Map<String, int> map) {
  String? best;
  int bestCount = -1;
  for (final MapEntry<String, int> e in map.entries) {
    if (e.value > bestCount) {
      best = e.key;
      bestCount = e.value;
    }
  }
  return best;
}

/// All recorded stats.
class StatsStore {
  final Map<String, CallSiteStats> _sites = <String, CallSiteStats>{};

  /// Frames in which at least one rebuild happened.
  int frames = 0;

  /// Rebuilds recorded.
  int events = 0;

  /// Number of call sites tracked.
  int get length => _sites.length;

  /// Clears everything.
  void clear() {
    _sites.clear();
    frames = 0;
    events = 0;
  }

  /// Records one rebuild.
  void record({
    required String widget,
    required String location,
    required FrameEvent event,
    required bool dirty,
    required bool? propsChanged,
    required List<String> changedDeps,
    bool propsCompared = true,
  }) {
    events++;
    final CallSiteStats s = _sites.putIfAbsent(
        '$widget@$location', () => CallSiteStats(widget, location));
    s.rebuilds++;
    bump(
        s.causes,
        dirty
            ? event.trigger.kind.name
            : 'parent rebuilt (${event.rootWidget})');
    bump(s.triggers, event.trigger.text);
    s.kinds[event.trigger.kind] = (s.kinds[event.trigger.kind] ?? 0) + 1;
    for (final String dep in changedDeps) {
      bump(s.changedDependencies, dep);
    }
    if (!dirty && propsCompared) {
      if (propsChanged == null) {
        s.propsUnknown++;
      } else if (!propsChanged) {
        s.wasted++;
      }
    }
  }

  /// Call sites sorted by rebuild count, highest first.
  List<CallSiteStats> sorted() => _sites.values.toList()
    ..sort(
        (CallSiteStats a, CallSiteStats b) => b.rebuilds.compareTo(a.rebuilds));

  /// Call sites of [widget]. Matches `BlocBuilder` and `BlocBuilder<A, B>`.
  List<CallSiteStats> sitesOf(String widget) => sorted()
      .where((CallSiteStats s) =>
          s.widget == widget || baseName(s.widget) == widget)
      .toList();
}

/// `BlocBuilder<A, B>` -> `BlocBuilder`.
String baseName(String type) {
  final int i = type.indexOf('<');
  return i < 0 ? type : type.substring(0, i);
}
