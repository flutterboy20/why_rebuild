import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_package.dart';

/// Where a widget was created.
class WidgetLocation {
  /// Creates a location.
  const WidgetLocation(this.short, this.local);

  /// Short `file:line`, e.g. `lib/main.dart:153`; null when unknown.
  final String? short;

  /// True when the widget was created by app code.
  final bool local;

  /// Location unknown (or not app code).
  static const WidgetLocation unknown = WidgetLocation(null, false);
}

/// Widget creation locations (`--track-widget-creation`, on by default in
/// debug), cached per element.
class LocationCache {
  /// Creates a cache using [origin] to decide what is app code.
  LocationCache(this.origin);

  /// Decides app vs third-party.
  final CodeOrigin origin;

  Expando<WidgetLocation> _cache = Expando<WidgetLocation>('why_rebuild.loc');

  /// Forgets every cached location.
  void clear() {
    _cache = Expando<WidgetLocation>('why_rebuild.loc');
  }

  /// The creation location of [element]'s widget.
  WidgetLocation of(Element element) {
    final WidgetLocation? cached = _cache[element];
    if (cached != null) {
      return cached;
    }
    final WidgetLocation loc = _compute(element.widget);
    _cache[element] = loc;
    return loc;
  }

  WidgetLocation _compute(Widget widget) {
    // Ask the inspector for just the creation location. A bare property node
    // avoids serializing the widget, which would run app debugFillProperties.
    final Map<String, Object?> json =
        InspectorSerializationDelegate(service: WidgetInspectorService.instance)
            .additionalNodeProperties(
                DiagnosticsProperty<Widget>('widget', widget));
    final Object? raw = json['creationLocation'];
    if (raw is! Map) {
      return WidgetLocation.unknown;
    }
    final String file = '${raw['file']}';
    if (!origin.isApp(file)) {
      return WidgetLocation.unknown;
    }
    return WidgetLocation('${origin.shortPath(file)}:${raw['line']}', true);
  }
}
