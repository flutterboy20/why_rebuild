import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/src/capture/devtools_yield.dart';
import 'package:why_rebuild/src/capture/schedule_stacks.dart';
import 'package:why_rebuild/src/capture/stack_frames.dart';
import 'package:why_rebuild/src/classify/friendly_names.dart';
import 'package:why_rebuild/src/locate/app_package.dart';

const String _config = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "flutter", "rootUri": "file:///C:/flutter/packages/flutter", "packageUri": "lib/"},
    {"name": "provider", "rootUri": "file:///C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/provider-6.1.5", "packageUri": "lib/"},
    {"name": "ui_kit", "rootUri": "../packages/ui_kit", "packageUri": "lib/"},
    {"name": "why_rebuild", "rootUri": "file:///C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/why_rebuild-0.1.0", "packageUri": "lib/"},
    {"name": "my_app", "rootUri": "../", "packageUri": "lib/"}
  ]
}
''';

void main() {
  final Uri configUri =
      Uri.parse('file:///C:/work/my%20app/.dart_tool/package_config.json');
  final List<PackageEntry> packages =
      CodeOrigin.parsePackageConfig(configUri, _config);
  final CodeOrigin exact = CodeOrigin.manual(
    appPackage: 'my_app',
    packages: packages,
    projectRoot: 'c:/work/my app/',
  );
  final CodeOrigin heuristic = CodeOrigin.manual(appPackage: 'my_app');

  test('package_config: relative rootUri = local', () {
    expect(<String, bool>{
      for (final PackageEntry p in packages) p.name: p.local
    }, <String, bool>{
      'flutter': false,
      'provider': false,
      'ui_kit': true,
      'why_rebuild': false,
      'my_app': true,
    });
  });

  test('exact mode: app vs third-party', () {
    expect(exact.isApp('package:my_app/main.dart'), isTrue);
    expect(exact.isApp('package:ui_kit/button.dart'), isTrue,
        reason: 'local path package');
    expect(exact.isApp('package:provider/provider.dart'), isFalse);
    expect(exact.isApp('package:flutter/src/widgets/framework.dart'), isFalse);
    expect(exact.isApp('package:why_rebuild/src/scanner.dart'), isFalse);
    expect(exact.isApp('file:///C:/work/my%20app/lib/main.dart'), isTrue);
    expect(
        exact.isApp('file:///C:/work/my%20app/test/widget_test.dart'), isTrue);
    expect(
        exact.isApp('file:///C:/work/my%20app/packages/ui_kit/lib/button.dart'),
        isTrue);
    expect(
        exact.isApp(
            'file:///C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/provider-6.1.5/lib/x.dart'),
        isFalse);
    expect(exact.isApp('dart:async'), isFalse);
  });

  test('heuristic mode: Windows pub cache is third-party (PoC bug)', () {
    expect(
        heuristic.isApp(
            'C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/provider-6.1.5/lib/x.dart'),
        isFalse);
    expect(
        heuristic.isApp(
            'file:///home/me/.pub-cache/hosted/pub.dev/bloc-9.0.0/lib/bloc.dart'),
        isFalse);
    expect(
        heuristic.isApp(
            'file:///C:/fvm/versions/3.47.0/packages/flutter/lib/src/widgets/basic.dart'),
        isFalse);
    expect(heuristic.isApp('file:///Users/me/app/lib/main.dart'), isTrue);
    expect(heuristic.isApp('package:my_app/main.dart'), isTrue);
    expect(heuristic.isApp('package:other/main.dart'), isFalse);
  });

  test('self is never app code', () {
    expect(heuristic.isSelf('package:why_rebuild/src/scanner.dart'), isTrue);
    expect(heuristic.isSelf('file:///C:/x/why_rebuild/lib/src/scanner.dart'),
        isTrue);
    expect(
        heuristic
            .isSelf('file:///C:/cache/why_rebuild-0.1.0/lib/src/scanner.dart'),
        isTrue);
    expect(heuristic.isSelf('file:///C:/x/why_rebuild/example/lib/main.dart'),
        isFalse);
    expect(heuristic.isSelf('package:why_rebuild_example/main.dart'), isFalse);
  });

  test('short paths are project-relative', () {
    expect(exact.shortPath('package:my_app/main.dart'), 'lib/main.dart');
    expect(exact.shortPath('package:ui_kit/button.dart'),
        'packages/ui_kit/lib/button.dart');
    expect(exact.shortPath('file:///C:/work/my%20app/test/a_test.dart'),
        'test/a_test.dart');
    expect(heuristic.shortPath('package:my_app/src/x.dart'), 'lib/src/x.dart');
    expect(heuristic.shortPath('file:///Users/me/app/lib/main.dart'),
        'lib/main.dart');
    expect(heuristic.shortPath('package:provider/provider.dart'),
        'package:provider/provider.dart');
  });

  test('app package from a stack', () {
    const String stack =
        '#0 WhyRebuild.install (package:why_rebuild/src/scanner.dart:90:5)\n'
        '#1 main (package:shop/main.dart:12:3)\n';
    expect(CodeOrigin.packageFromStack(stack), 'shop');
    expect(
        CodeOrigin.packageFromStack('#0 x (package:flutter_test/a.dart:1:1)'),
        isNull);
  });

  test('stack frames parse the Dart VM format', () {
    final List<StackFrameInfo> frames = parseStack(<String>[
      '#0      State.setState (package:flutter/src/widgets/framework.dart:1221:5)',
      '#1      HomePageState.addToCart (package:my_app/main.dart:144:5)',
      '#2      HomePageState.build.<anonymous closure> (package:my_app/main.dart:160:30)',
      '<asynchronous suspension>',
      '(elided 3 frames from dart:async)',
    ], heuristic);
    expect(frames, hasLength(3));
    expect(frames[0].matches('setState', 'widgets/framework.dart'), isTrue);
    expect(frames[1].method, 'HomePageState.addToCart');
    expect(frames[1].location, 'lib/main.dart:144');
    expect(frames[1].isApp, isTrue);
    expect(frames[2].method, 'HomePageState.build');
    expect(frames[0].package, 'package:flutter');
  });

  test('schedule stacks: label + stack pairs, resort noise swallowed', () {
    final ScheduleStackCollector c = ScheduleStackCollector();
    expect(
        c.handle('scheduleBuildFor() called for Foo(dirty) (ALREADY IN LIST)',
            active: true),
        isTrue);
    expect(
        c.handle('#0 a (package:x/y.dart:1:1)\n#1 b (package:x/y.dart:2:1)',
            active: true),
        isTrue);
    expect(c.stackFor('Foo(dirty)'), hasLength(2));
    expect(c.handle('BuildOwner.scheduleBuildFor() called; ...', active: true),
        isTrue);
    expect(c.handle('#0 stack of the resort message', active: true), isTrue);
    expect(
        c.handle("...the build scope's dirty list is now: [Foo]", active: true),
        isTrue);
    expect(c.handle('hello from the app', active: true), isFalse);
    expect(
        c.handle('scheduleBuildFor() called for Bar', active: false), isFalse,
        reason: 'someone else turned the flag on');
  });

  test('DevTools toggle log lines', () {
    expect(
        DevToolsToggle.parse('service extension method received: '
            'ext.flutter.inspector.trackRebuildDirtyWidgets({enabled: true})'),
        isTrue);
    expect(
        DevToolsToggle.parse('service extension method received: '
            'ext.flutter.inspector.trackRebuildDirtyWidgets({enabled: false})'),
        isFalse);
    expect(
        DevToolsToggle.parse(
            'service extension method received: ext.flutter.debugPaint({})'),
        isNull);
    expect(DevToolsToggle.isInstrumentationLine('Action "x" took 3ms'), isTrue);
  });

  test('friendly names', () {
    expect(friendlyType('_InheritedProviderScope<CartModel?>'),
        'Provider<CartModel>');
    expect(friendlyType('_InheritedTheme'), 'Theme');
    expect(friendlyType('_LocalizationsScope'), 'Localizations');
    expect(friendlyType('UncontrolledProviderScope'), 'Riverpod ProviderScope');
    expect(friendlyType('ProductTile'), 'ProductTile');
  });
}
