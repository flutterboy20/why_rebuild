import '../capture/stack_frames.dart';

/// Package name -> state library name. Detected from stack frames only; the
/// libraries are never imported.
const Map<String, String> knownStateLibraries = <String, String>{
  'flutter_riverpod': 'Riverpod',
  'riverpod': 'Riverpod',
  'hooks_riverpod': 'Riverpod',
  'provider': 'provider',
  'flutter_bloc': 'Bloc',
  'bloc': 'Bloc',
  'get': 'GetX',
  'mobx': 'MobX',
  'flutter_mobx': 'MobX',
  'signals': 'Signals',
  'signals_core': 'Signals',
  'signals_flutter': 'Signals',
  'preact_signals': 'Signals',
  'flutter_hooks': 'flutter_hooks',
  'flutter_redux': 'Redux',
  'redux': 'Redux',
  'flutter_solidart': 'Solidart',
  'solidart': 'Solidart',
  'watch_it': 'watch_it',
  'stacked': 'Stacked',
};

final RegExp _packageName = RegExp(r'^package:([^/]+)/');

/// The first known state library in [frames], or null.
String? stateLibraryOf(List<StackFrameInfo> frames) {
  for (final StackFrameInfo f in frames) {
    final RegExpMatch? m = _packageName.firstMatch(f.uri);
    if (m != null) {
      final String? library = knownStateLibraries[m.group(1)];
      if (library != null) {
        return library;
      }
    }
  }
  return null;
}
