// One test per "never break anything" requirement (design spec section 3).

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/src/extensions/service_extensions.dart';
import 'package:why_rebuild/testing.dart';

import 'support/fixtures.dart';
import 'support/helpers.dart';

void main() {
  testWidgets('R4: uninstall restores every global it touched',
      (WidgetTester tester) async {
    final DebugPrintCallback before = debugPrint;
    scan.install();
    try {
      expect(debugPrint, isNot(same(before)));
      expect(debugInstrumentationEnabled, isTrue);
      expect(debugOnRebuildDirtyWidget, isNotNull);
      expect(debugPrintScheduleBuildForStacks, isTrue);
    } finally {
      scan.uninstall();
    }
    expect(debugPrint, same(before));
    expect(debugInstrumentationEnabled, isFalse);
    expect(debugOnRebuildDirtyWidget, isNull);
    expect(debugPrintScheduleBuildForStacks, isFalse);
    expect(scan.isInstalled, isFalse);
  });

  testWidgets('R10: double install, reinstall and hot reload are safe',
      (WidgetTester tester) async {
    scan.install();
    try {
      scan.install(); // hot restart re-runs main(); must not throw
      expect(scan.isInstalled, isTrue);
    } finally {
      scan.uninstall();
    }
    scan.uninstall(); // twice is fine too
    scan.install(); // extensions and frame callback are not registered twice
    try {
      scan.reset();
      await tester.pumpWidget(const DemoApp());
      // Hot reload. reassembleApplication awaits a frame, so pump instead of
      // awaiting it (the test binding only draws frames on pump).
      final Future<void> reload = tester.binding.reassembleApplication();
      await tester.pump();
      await reload;
      expect(scan.report().top, isEmpty,
          reason: 'hot reload is not an app cause');
      homeKey.currentState!.addToCart();
      await tester.pump();
      expect(site('ProductTile'), isNotNull);
    } finally {
      scan.uninstall();
    }
  });

  scanTest('R2: errors inside capture never reach the app; detaches after 20',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    scan.debugResetWarnings();
    scan.debugThrowInCapture = true;
    try {
      for (int i = 0; i < 3; i++) {
        homeKey.currentState!.addToCart();
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(scan.state, ScanState.disabledAfterErrors);
      expect(debugOnRebuildDirtyWidget, isNull);
      final ScanStatus status = scan.status();
      expect(status.errors, greaterThanOrEqualTo(WhyRebuild.maxErrors));
      expect(status.lastError, contains('debugThrowInCapture'));
      expect(status.toJson()['state'], 'disabledAfterErrors');
      // The app keeps working.
      homeKey.currentState!.addToCart();
      await tester.pump();
      expect(find.text('Cart: 4'), findsOneWidget);
    } finally {
      scan.debugThrowInCapture = false;
    }
  });

  scanTest('R2: a throwing debugFillProperties does not break the scan',
      (WidgetTester tester) async {
    await tester.pumpWidget(Counter(
      builder: (int count) => Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: <Widget>[Text('$count'), const BrokenProps()]),
      ),
    ));
    final CounterState counter = tester.state(find.byType(Counter));
    counter.increment();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(scan.state, ScanState.recording);
    expect(scan.status().errors, 0, reason: scan.status().lastError);
  });

  testWidgets("R5: the app's own logs are forwarded; scanner noise is not",
      (WidgetTester tester) async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback before = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    try {
      scan.install();
      try {
        await tester.pumpWidget(const DemoApp());
        homeKey.currentState!.addToCart();
        await tester.pump();
        debugPrint('hello from the app');
        debugPrint('service extension method received: ext.flutter.foo({})');
      } finally {
        scan.uninstall();
      }
    } finally {
      debugPrint = before;
    }
    expect(printed, contains('hello from the app'));
    expect(printed.where((String? m) => m!.startsWith('scheduleBuildFor()')),
        isEmpty);
    expect(printed.where((String? m) => m!.startsWith('#')), isEmpty,
        reason: 'no stacks');
    expect(
        printed.where((String? m) => m!.startsWith('service extension method')),
        isEmpty);
  });

  testWidgets('R5: instrumentation logs the developer enabled are kept',
      (WidgetTester tester) async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback before = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    debugInstrumentationEnabled = true;
    try {
      scan.install();
      try {
        debugPrint('service extension method received: ext.flutter.foo({})');
      } finally {
        scan.uninstall();
      }
      expect(debugInstrumentationEnabled, isTrue,
          reason: 'restored to what it was');
    } finally {
      debugPrint = before;
      debugInstrumentationEnabled = false;
    }
    expect(printed,
        contains('service extension method received: ext.flutter.foo({})'));
  });

  testWidgets('R6: a problem is reported exactly once',
      (WidgetTester tester) async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback before = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    scan.debugResetWarnings();
    void otherTool(Element e, bool b) {}
    debugOnRebuildDirtyWidget = otherTool;
    try {
      scan.install();
      try {
        await tester.pumpWidget(const DemoApp());
        for (int i = 0; i < 5; i++) {
          homeKey.currentState!.addToCart();
          await tester.pump();
        }
        expect(scan.state, ScanState.blockedByOtherTool);
      } finally {
        scan.uninstall();
      }
    } finally {
      debugOnRebuildDirtyWidget = null;
      debugPrint = before;
    }
    expect(printed.where((String? m) => m!.startsWith('why_rebuild:')),
        hasLength(1));
    expect(printed.where((String? m) => m!.contains('another tool')),
        hasLength(1));
  });

  testWidgets('no output by default', (WidgetTester tester) async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback before = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    try {
      scan.install();
      try {
        await tester.pumpWidget(const DemoApp());
        for (int i = 0; i < 3; i++) {
          homeKey.currentState!.addToCart();
          keyboardKey.currentState!.toggleKeyboard();
          await tester.pump();
        }
        spinnerKey.currentState!.start();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        spinnerKey.currentState!.stop();
      } finally {
        scan.uninstall();
      }
    } finally {
      debugPrint = before;
    }
    expect(printed, isEmpty);
  });

  group('R9: service extensions never throw', () {
    late Map<String, ExtensionHandler> handlers;

    setUp(() => handlers = serviceExtensionHandlers(scan));

    Future<Map<String, Object?>> call(String name,
        [Map<String, String> p = const <String, String>{}]) async {
      final developer.ServiceExtensionResponse r =
          await handlers['ext.why_rebuild.$name']!(p);
      expect(r.errorCode, isNull, reason: r.errorDetail);
      return jsonDecode(r.result!) as Map<String, Object?>;
    }

    test('all names are registered', () {
      expect(
          handlers.keys,
          unorderedEquals(<String>[
            for (final String n in <String>[
              'status',
              'record',
              'report',
              'why',
              'reset',
              'pause',
              'resume'
            ])
              'ext.why_rebuild.$n',
          ]));
    });

    test('bad params give invalidParams with a human message', () async {
      final developer.ServiceExtensionResponse r1 =
          await handlers['ext.why_rebuild.record']!(
              <String, String>{'action': 'jump'});
      expect(r1.errorCode, developer.ServiceExtensionResponse.invalidParams);
      expect(r1.errorDetail, contains('"start" or "stop"'));

      final developer.ServiceExtensionResponse r2 =
          await handlers['ext.why_rebuild.report']!(
              <String, String>{'limit': 'lots'});
      expect(r2.errorCode, developer.ServiceExtensionResponse.invalidParams);
      expect(r2.errorDetail, contains('limit'));
    });

    test('work when the scanner is not installed', () async {
      scan.reset();
      expect((await call('status'))['state'], 'paused');
      expect((await call('status'))['note'], contains('Not installed'));
      expect((await call('report'))['top'], isEmpty);
      expect((await call('why', <String, String>{'widget': 'X'}))['callSites'],
          isEmpty);
      expect((await call('why'))['wastedWidgets'], isEmpty);
    });

    testWidgets('agent session: record start, reproduce, stop, why',
        (WidgetTester tester) async {
      scan.install();
      try {
        await tester.pumpWidget(const DemoApp());
        expect(
            (await call(
                'record', <String, String>{'action': 'start'}))['state'],
            'recording');
        homeKey.currentState!.addToCart();
        await tester.pump();
        final Map<String, Object?> report = await call(
            'record', <String, String>{'action': 'stop', 'limit': '3'});
        expect(report['state'], 'paused');
        expect(report['top'], hasLength(3));

        final Map<String, Object?> why =
            await call('why', <String, String>{'widget': 'ProductTile'});
        final Map<String, Object?> site =
            (why['callSites']! as List<Object?>).first! as Map<String, Object?>;
        expect(site['wasted'], site['rebuilds']);
        expect(site['fixHint'], contains('const'));

        final Map<String, Object?> wasted = await call('why');
        final List<Object?> names = <Object?>[
          for (final Object? w in wasted['wastedWidgets']! as List<Object?>)
            (w! as Map<String, Object?>)['widget'],
        ];
        expect(names, contains('ProductTile'));
        expect(names, isNot(contains('CartBadge')));

        expect((await call('resume'))['state'], 'recording');
        expect((await call('pause'))['state'], 'paused');
        expect((await call('reset'))['rebuildsRecorded'], 0);
      } finally {
        scan.uninstall();
      }
    });
  });
}
