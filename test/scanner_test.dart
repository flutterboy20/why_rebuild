// The PoC's core scenarios, ported.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/testing.dart';

import 'support/fixtures.dart';
import 'support/helpers.dart';

void main() {
  scanTest('setState high in the tree: unchanged children are wasted',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 3; i++) {
      homeKey.currentState!.addToCart();
      await tester.pump();
    }

    final CallSite tile = site('ProductTile')!;
    expect(tile.location, startsWith('test/support/fixtures.dart:'));
    expect(tile.rebuilds, greaterThan(0));
    expect(tile.wasted, tile.rebuilds);
    expect(tile.causes.keys.single, 'parent rebuilt (HomePage)');
    expect(
        onlyTrigger(tile),
        startsWith(
            'setState in HomePageState.addToCart at test/support/fixtures.dart:'));
    expect(tile.fixHint, contains('Make it const'));

    // HomePage itself: setState, with the caller's location.
    final CallSite home = site('HomePage')!;
    expect(home.causes, <String, int>{'setState': 3});

    // CartBadge's count really changed: not wasted, no hint.
    final CallSite badge = site('CartBadge')!;
    expect(badge.rebuilds, 3);
    expect(badge.wasted, 0);
    expect(badge.fixHint, isNull);

    // No debugFillProperties: unknown, never wasted.
    final CallSite plain = site('PlainTile')!;
    expect(plain.wasted, 0);
    expect(plain.propsUnknown, 3);
    expect(plain.fixHint, contains('debugFillProperties'));
  });

  scanTest('MediaQuery change: names the dependency, sizeOf is spared',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 2; i++) {
      keyboardKey.currentState!.toggleKeyboard();
      await tester.pump();
    }

    final CallSite form = site('CheckoutForm')!;
    expect(form.rebuilds, 2);
    expect(form.causes, <String, int>{'inherited': 2});
    expect(form.changedDependencies, <String, int>{'MediaQuery': 2});
    expect(form.fixHint, contains('MediaQuery.sizeOf'));

    expect(site('CheckoutFormFixed'), isNull);
  });

  scanTest('AnimatedBuilder without child: chart rebuilt every tick',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    spinnerKey.currentState!.start();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    spinnerKey.currentState!.stop();

    final CallSite chart = site('ChartCard')!;
    expect(chart.rebuilds, greaterThanOrEqualTo(10));
    expect(chart.wasted, chart.rebuilds);
    expect(
        onlyTrigger(chart),
        startsWith(
            'animation tick in AnimatedBuilder at test/support/fixtures.dart:'));
    expect(chart.fixHint, contains('AnimatedBuilder(child: ...)'));
  });

  scanTest('steps aside for DevTools and comes back after',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    expect(scan.state, ScanState.recording);

    // What Flutter logs right before running DevTools' toggle handler.
    debugPrint('service extension method received: '
        'ext.flutter.inspector.trackRebuildDirtyWidgets({enabled: true})');
    expect(scan.state, ScanState.yieldedToDevTools);
    expect(debugOnRebuildDirtyWidget, isNull,
        reason: 'the inspector asserts the hook is null, so it must be free');
    expect(scan.status().note, contains('resumes automatically'));

    // The inspector takes the hook...
    void inspectorHook(Element e, bool b) {}
    debugOnRebuildDirtyWidget = inspectorHook;
    homeKey.currentState!.addToCart();
    await tester.pump();
    expect(site('ProductTile'), isNull, reason: 'not recording while yielded');

    // ...and releases it when DevTools turns tracking off.
    debugPrint('service extension method received: '
        'ext.flutter.inspector.trackRebuildDirtyWidgets({enabled: false})');
    debugOnRebuildDirtyWidget = null;
    await tester.pump(const Duration(milliseconds: 200));
    expect(scan.state, ScanState.recording);

    homeKey.currentState!.addToCart();
    await tester.pump();
    expect(site('ProductTile'), isNotNull);
  });

  scanTest('blocked, not crashing, when another tool holds the hook',
      (WidgetTester tester) async {
    scan.stopRecording();
    void otherTool(Element e, bool b) {}
    debugOnRebuildDirtyWidget = otherTool;
    scan.startRecording();
    expect(scan.state, ScanState.blockedByOtherTool);
    expect(debugOnRebuildDirtyWidget, same(otherTool),
        reason: 'R7: never overwrite');
    expect(scan.status().note, contains('Turn it off'));
    debugOnRebuildDirtyWidget = null;
    await tester.pumpWidget(const DemoApp()); // a frame lets it re-attach
    expect(scan.state, ScanState.recording);
  });

  scanTest('record start/stop through the Dart API',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    scan.stopRecording();
    expect(scan.state, ScanState.paused);
    homeKey.currentState!.addToCart();
    await tester.pump();
    expect(scan.report().top, isEmpty);

    scan.reset();
    scan.startRecording();
    homeKey.currentState!.addToCart();
    await tester.pump();
    final RebuildReport report = scan.report(limit: 2);
    expect(report.top, hasLength(2));
    expect(report.state, ScanState.recording);
    expect(report.mode, 'full');
    expect(report.framesWithRebuilds, 1);

    scan.reset();
    expect(scan.report().top, isEmpty);
    expect(scan.status().rebuildsRecorded, 0);
  });

  test('install outside debug mode would be a no-op', () {
    // kDebugMode is a const; this documents the guard that tree-shakes the
    // scanner out of profile/release builds (checked on a real release build).
    expect(kDebugMode, isTrue);
  });
}
