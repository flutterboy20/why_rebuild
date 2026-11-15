import 'package:flutter/widgets.dart';

/// `name=value` of each diagnostic property (`debugFillProperties`) of
/// [widget]. A parent rebuild is wasted when this is identical before and
/// after.
///
/// Returns null when the widget has no diagnostic properties (props unknown:
/// never reported as wasted) or when its `debugFillProperties` throws.
String? propsSignature(Widget widget) {
  try {
    final List<DiagnosticsNode> props =
        widget.toDiagnosticsNode().getProperties();
    if (props.isEmpty) {
      return null;
    }
    return props
        .map((DiagnosticsNode p) => '${p.name}=${p.toDescription()}')
        .join('|');
  } catch (_) {
    // A broken debugFillProperties in app code must never break the scan.
    return null;
  }
}
