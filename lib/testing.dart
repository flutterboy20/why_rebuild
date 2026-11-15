/// Test helpers: run widget tests with the scanner installed, and fail a test
/// when an interaction rebuilds too much, with the cause chain and a fix hint
/// in the failure message.
///
/// ```dart
/// import 'package:why_rebuild/testing.dart';
///
/// scanTest('cart tap stays cheap', (tester) async {
///   await tester.pumpWidget(const MyApp());
///   await expectRebuildBudget(tester, () => tester.tap(find.text('Add')),
///       maxRebuilds: 30, forbidWasted: ['ProductTile']);
/// });
/// ```
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'why_rebuild.dart';

export 'why_rebuild.dart';

/// Like `testWidgets`, with [WhyRebuild] installed for the duration of the
/// body.
///
/// flutter_test checks the framework's debug globals right after the test
/// body, before `tearDown` runs, so the scanner must be installed and
/// uninstalled inside the body. This helper does exactly that.
///
/// [appPackage] is detected from package_config.json when omitted.
/// [captureStacks] false runs the test in lite mode.
void scanTest(
  String description,
  WidgetTesterCallback body, {
  String? appPackage,
  bool captureStacks = true,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
}) {
  testWidgets(
    description,
    (WidgetTester tester) async {
      final WhyRebuild scan = WhyRebuild.instance;
      scan.install(appPackage: appPackage, captureStacks: captureStacks);
      scan.reset();
      try {
        await body(tester);
      } finally {
        scan.uninstall();
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
  );
}

/// Runs [action], pumps [pumps] frames, and fails the test when the rebuilds
/// it caused exceed the budget.
///
/// * [maxRebuilds]: most app-widget rebuilds allowed in total.
/// * [maxRebuildsPerWidget]: most rebuilds allowed per widget name, e.g.
///   `{'ProductTile': 0}`.
/// * [forbidWasted]: widgets that must not have a single wasted rebuild.
///
/// The failure message explains each violation the way [WhyRebuild.why]
/// does: causes, triggers, and a fix hint.
///
/// Must run inside [scanTest]. Cubit/stream updates land a microtask later,
/// which is why the default is two pumps.
Future<void> expectRebuildBudget(
  WidgetTester tester,
  FutureOr<void> Function() action, {
  int? maxRebuilds,
  Map<String, int> maxRebuildsPerWidget = const <String, int>{},
  List<String> forbidWasted = const <String>[],
  int pumps = 2,
}) async {
  final WhyRebuild scan = WhyRebuild.instance;
  if (!scan.isInstalled) {
    fail(
        'expectRebuildBudget needs the scanner: use scanTest(...) instead of testWidgets(...).');
  }
  if (scan.state != ScanState.recording) {
    fail(
        'why_rebuild is not recording (state: ${scan.state.name}). ${scan.status().note ?? ''}');
  }
  scan.reset();
  await action();
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }

  final RebuildReport report = scan.report(limit: 1 << 30);
  final List<String> problems = <String>[];

  final int total = report.totalRebuilds;
  if (maxRebuilds != null && total > maxRebuilds) {
    final StringBuffer b = StringBuffer(
        'Expected at most $maxRebuilds rebuilds, got $total. Most rebuilt:\n');
    for (final RebuildSite s in report.top.take(5)) {
      b.writeln(
          '  ${s.widget} (${s.location}): ${s.rebuilds} rebuilds, ${s.wasted} wasted'
          ' <- ${s.trigger}');
    }
    final Iterable<String> wastedNames = <String>{
      for (final RebuildSite s in report.top)
        if (s.wasted > 0) s.widget,
    }.take(3);
    for (final String name in wastedNames) {
      b.writeln(scan.why(name).describe());
    }
    problems.add(b.toString().trimRight());
  }

  for (final MapEntry<String, int> limit in maxRebuildsPerWidget.entries) {
    final WhyReport why = scan.why(limit.key);
    if (why.rebuilds > limit.value) {
      problems
          .add('Expected ${limit.key} to rebuild at most ${limit.value} times, '
              'got ${why.rebuilds}.\n${why.describe()}');
    }
  }

  for (final String name in forbidWasted) {
    final WhyReport why = scan.why(name);
    if (why.wasted > 0) {
      problems.add(
          'Expected no wasted rebuilds of $name, got ${why.wasted}.\n${why.describe()}');
    }
  }

  if (problems.isNotEmpty) {
    fail(problems.join('\n\n'));
  }
}
