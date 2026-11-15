import '../model/stats.dart';

/// A fix suggestion for [s], picked from its DOMINANT cause (one stray
/// rebuild, e.g. under a route's AnimatedBuilder, must not decide the hint).
String? fixHint(CallSiteStats s) {
  final int parent = s.parentRebuilds;
  final String topTrigger = s.topTrigger ?? '';
  final String topCause = s.topCause ?? '';

  if (s.changedDependencies.containsKey('MediaQuery')) {
    return 'Depends on all of MediaQuery, so any change (keyboard insets, padding) '
        'rebuilds it. If it only needs the size, use MediaQuery.sizeOf(context) '
        '(or paddingOf, viewInsetsOf, ...).';
  }
  final bool animated = topTrigger.contains('animation tick') ||
      topTrigger.contains('animation or listenable') ||
      topCause.contains('(AnimatedBuilder)') ||
      topCause.contains('(ListenableBuilder)');
  if (parent > 0 && s.wasted == parent && animated) {
    return 'Rebuilt on every animation tick with unchanged props. Build it once and '
        'pass it as AnimatedBuilder(child: ...).';
  }
  if (parent > 0 && s.wasted == parent) {
    return 'Rebuilt only because an ancestor rebuilt; its props never changed. Make '
        'it const, or move the state that changes ($topTrigger) into a smaller widget.';
  }
  if (parent > 0 && s.propsUnknown > 0) {
    return 'Props could not be compared (the widget has no debugFillProperties). Add '
        'debugFillProperties so why_rebuild can detect wasted rebuilds.';
  }
  return null;
}
