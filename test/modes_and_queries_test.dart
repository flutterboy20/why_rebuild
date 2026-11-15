import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/src/locate/app_package.dart';
import 'package:why_rebuild/testing.dart';

import 'support/fixtures.dart';
import 'support/library_like.dart';
import 'support/helpers.dart';

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  scanTest('lite mode (captureStacks: false) still gives a useful cause',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    homeKey.currentState!.addToCart();
    await tester.pump();
    keyboardKey.currentState!.toggleKeyboard();
    await tester.pump();

    expect(scan.mode, 'lite');
    expect(onlyTrigger(site('HomePage')!),
        startsWith('state changed in HomePage'));
    expect(site('ProductTile')!.wasted, site('ProductTile')!.rebuilds);
    expect(onlyTrigger(site('CheckoutForm')!), 'MediaQuery changed');
    expect(scan.why('HomePage').note, contains('best guess'));
    expect(scan.report().note, contains('best guess'));
    expect(scan.state, ScanState.recording);
    expect(debugPrintScheduleBuildForStacks, isFalse,
        reason: 'no stacks in lite mode');
  }, captureStacks: false);

  testWidgets(
      'R8: falls back to lite mode when stacks stop arriving, and says so once',
      (WidgetTester tester) async {
    final List<String?> printed = <String?>[];
    final DebugPrintCallback before = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => printed.add(message);
    scan.debugResetWarnings();
    try {
      scan.install();
      try {
        await tester.pumpWidget(const DemoApp());
        scan.debugDropStacks = true;
        for (int i = 0; i < WhyRebuild.stackMissesBeforeLite + 5; i++) {
          homeKey.currentState!.addToCart();
          await tester.pump();
        }
        expect(scan.mode, 'lite');
        expect(scan.status().note, contains('stack capture stopped working'));
        expect(debugPrintScheduleBuildForStacks, isFalse);
        expect(scan.state, ScanState.recording);
      } finally {
        scan.debugDropStacks = false;
        scan.uninstall();
      }
    } finally {
      debugPrint = before;
    }
    expect(printed.where((String? m) => m!.contains('switched to lite mode')),
        hasLength(1));
  });

  scanTest('why() matches generic widgets by base name',
      (WidgetTester tester) async {
    await tester
        .pumpWidget(Counter(builder: (int c) => _wrap(Holder<int>(value: c))));
    tester.state<CounterState>(find.byType(Counter)).increment();
    await tester.pump();

    expect(scan.why('Holder').callSites, hasLength(1));
    expect(scan.why('Holder<int>').callSites, hasLength(1));
    expect(scan.why('Hold').callSites, isEmpty);
    expect(scan.why('Holder').callSites.single.wasted, 0,
        reason: 'value changed');
  });

  scanTest(
      'framework-internal cascade roots are named with the nearest app ancestor',
      (WidgetTester tester) async {
    CodeOrigin.debugThirdPartyPaths = <String>{'library_like.dart'};
    addTearDown(() => CodeOrigin.debugThirdPartyPaths = <String>{});
    final ValueNotifier<int> notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(_wrap(Column(children: <Widget>[
      // LibraryPanel stands in for a library widget: its internal
      // ValueListenableBuilder rebuilds the app's Leaf.
      // ignore: prefer_const_constructors
      LibraryPanel(notifier: notifier, builder: (int v) => Leaf(label: 'x')),
    ])));
    notifier.value++;
    await tester.pump();

    final CallSite leaf = site('Leaf')!;
    expect(leaf.causes.keys.single,
        'parent rebuilt (ValueListenableBuilder<int> under LibraryPanel)');
  });

  scanTest('ValueListenableBuilder: listenable, names who changed the value',
      (WidgetTester tester) async {
    final ValueNotifier<int> notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(_wrap(ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (BuildContext context, int v, Widget? child) =>
          Column(children: <Widget>[Text('$v'), const Leaf(label: 'static')]),
    )));
    void bump() => notifier.value++;
    bump();
    await tester.pump();

    final CallSite builder = site('ValueListenableBuilder')!;
    expect(builder.causes, <String, int>{'listenable': 1});
    expect(
        onlyTrigger(builder),
        startsWith(
            'listenable notified by main.bump at test/modes_and_queries_test.dart:'));
    expect(site('Leaf'), isNull, reason: 'a const child is never rebuilt');
  });

  scanTest('StreamBuilder and FutureBuilder: a new snapshot',
      (WidgetTester tester) async {
    final StreamController<int> stream = StreamController<int>();
    addTearDown(stream.close);
    final Completer<String> future = Completer<String>();
    await tester.pumpWidget(_wrap(Column(children: <Widget>[
      StreamBuilder<int>(
        stream: stream.stream,
        builder: (BuildContext context, AsyncSnapshot<int> s) =>
            Leaf(label: 'stream ${s.data}'),
      ),
      FutureBuilder<String>(
        future: future.future,
        builder: (BuildContext context, AsyncSnapshot<String> s) =>
            Leaf(label: 'future ${s.data}'),
      ),
    ])));
    stream.add(1);
    future.complete('done');
    await tester.pump();
    await tester.pump();

    expect(onlyTrigger(site('StreamBuilder')!),
        startsWith('new snapshot in StreamBuilder<int> at test/'));
    expect(onlyTrigger(site('FutureBuilder')!),
        startsWith('new snapshot in FutureBuilder<String> at test/'));
    expect(scan.why('Leaf').callSites.every((CallSite c) => c.wasted == 0),
        isTrue);
  });

  scanTest('wasted() lists widgets with wasted rebuilds, most wasted first',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 2; i++) {
      homeKey.currentState!.addToCart();
      await tester.pump();
    }
    final WastedReport report = scan.wasted(limit: 50);
    final List<String> names = <String>[
      for (final RebuildSite s in report.widgets) s.widget
    ];
    expect(names, contains('ProductTile'));
    expect(names, isNot(contains('CartBadge')));
    expect(names, isNot(contains('PlainTile')));
    for (int i = 1; i < report.widgets.length; i++) {
      expect(report.widgets[i - 1].wasted,
          greaterThanOrEqualTo(report.widgets[i].wasted));
    }
    expect(scan.wasted(limit: 1).widgets, hasLength(1));
  });

  scanTest('responses stay small: at most 8 distinct triggers per call site',
      (WidgetTester tester) async {
    final List<ValueNotifier<int>> notifiers = <ValueNotifier<int>>[
      for (int i = 0; i < 12; i++) ValueNotifier<int>(0),
    ];
    await tester.pumpWidget(_wrap(Column(children: <Widget>[
      for (final ValueNotifier<int> n in notifiers)
        ValueListenableBuilder<int>(
          valueListenable: n,
          builder: (BuildContext context, int v, Widget? child) =>
              Leaf(label: '$v'),
        ),
    ])));
    // Each notifier is bumped from a different line, so triggers differ.
    notifiers[0].value++;
    await tester.pump(); // ignore: always_put_control_body_on_new_line
    notifiers[1].value++;
    await tester.pump();
    notifiers[2].value++;
    await tester.pump();
    notifiers[3].value++;
    await tester.pump();
    notifiers[4].value++;
    await tester.pump();
    notifiers[5].value++;
    await tester.pump();
    notifiers[6].value++;
    await tester.pump();
    notifiers[7].value++;
    await tester.pump();
    notifiers[8].value++;
    await tester.pump();
    notifiers[9].value++;
    await tester.pump();
    final CallSite leaf = site('Leaf')!;
    expect(leaf.triggers.length, lessThanOrEqualTo(9)); // 8 + "(other)"
    expect(leaf.triggers['(other)'], isNotNull);
    for (final ValueNotifier<int> n in notifiers) {
      n.dispose();
    }
  });
}
