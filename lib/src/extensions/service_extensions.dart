import 'dart:convert';
import 'dart:developer' as developer;

import '../scanner.dart';

/// Prefix of every service extension this package registers.
const String extensionPrefix = 'ext.why_rebuild.';

int _limit(Map<String, String> p) {
  final String? raw = p['limit'];
  if (raw == null || raw.isEmpty) {
    return 10;
  }
  final int? value = int.tryParse(raw);
  if (value == null || value < 1) {
    throw ArgumentError('"limit" must be a positive integer, got "$raw".');
  }
  return value;
}

/// A service extension handler: params in, response out. Never throws.
typedef ExtensionHandler = Future<developer.ServiceExtensionResponse> Function(
    Map<String, String> params);

/// Builds the `ext.why_rebuild.*` handlers, keyed by full method name.
/// Handlers never throw: they return a result or an error response with a
/// human message.
Map<String, ExtensionHandler> serviceExtensionHandlers(WhyRebuild scan) {
  final Map<String, ExtensionHandler> handlers = <String, ExtensionHandler>{};

  void register(String name, Object? Function(Map<String, String> p) handler) {
    handlers['$extensionPrefix$name'] = (Map<String, String> p) async {
      try {
        return developer.ServiceExtensionResponse.result(
            jsonEncode(handler(p)));
      } on ArgumentError catch (e) {
        return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams, '${e.message}');
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'why_rebuild: $e');
      }
    };
  }

  register('status', (_) => scan.status().toJson());
  register('report',
      (Map<String, String> p) => scan.report(limit: _limit(p)).toJson());
  register('why', (Map<String, String> p) {
    final String? widget = p['widget'];
    if (widget == null || widget.isEmpty) {
      // No widget named: list the widgets with wasted rebuilds, so an agent
      // can start without knowing names.
      return scan.wasted(limit: _limit(p)).toJson();
    }
    return scan.why(widget).toJson();
  });
  register('reset', (_) {
    scan.reset();
    return scan.status().toJson();
  });
  // Agent-friendly session: start clears old data; stop returns the report.
  register('record', (Map<String, String> p) {
    switch (p['action']) {
      case 'start':
        scan.reset();
        scan.startRecording();
        return scan.status().toJson();
      case 'stop':
        scan.stopRecording();
        return scan.report(limit: _limit(p)).toJson();
      default:
        throw ArgumentError('Pass "action": "start" or "stop".');
    }
  });
  register('pause', (_) {
    scan.stopRecording();
    return scan.status().toJson();
  });
  register('resume', (_) {
    scan.startRecording();
    return scan.status().toJson();
  });
  return handlers;
}

/// Registers every handler with the VM service.
///
/// Must be called at most once per isolate (`registerExtension` throws on a
/// second registration); [WhyRebuild.install] guards that.
void registerServiceExtensions(WhyRebuild scan) {
  serviceExtensionHandlers(scan)
      .forEach((String name, ExtensionHandler handler) {
    developer.registerExtension(
        name, (String method, Map<String, String> p) => handler(p));
  });
}
