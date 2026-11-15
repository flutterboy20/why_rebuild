import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/testing.dart';

import 'support/fixtures.dart';

void main() {
  scanTest('a cheap interaction passes its budget',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await expectRebuildBudget(
      tester,
      () => keyboardKey.currentState!.toggleKeyboard(),
      maxRebuildsPerWidget: <String, int>{
        'CheckoutFormFixed': 0,
        'ProductTile': 0
      },
    );
  });

  scanTest('a wasted rebuild fails with the cause chain and a fix hint',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    TestFailure? failure;
    try {
      await expectRebuildBudget(
        tester,
        () => tester.tap(find.text('Add to cart')),
        forbidWasted: <String>['ProductTile'],
      );
    } on TestFailure catch (e) {
      failure = e;
    }
    expect(failure, isNotNull);
    final String message = failure!.message!;
    expect(message, contains('Expected no wasted rebuilds of ProductTile'));
    expect(message, contains('cause:   parent rebuilt (HomePage)'));
    expect(
        message,
        contains(
            'trigger: setState in HomePageState.addToCart at test/support/fixtures.dart:'));
    expect(
        message, contains('fix:     Rebuilt only because an ancestor rebuilt'));
  });

  scanTest('a total budget lists the most rebuilt widgets',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    TestFailure? failure;
    try {
      await expectRebuildBudget(tester, () => homeKey.currentState!.addToCart(),
          maxRebuilds: 2);
    } on TestFailure catch (e) {
      failure = e;
    }
    expect(failure!.message, startsWith('Expected at most 2 rebuilds, got '));
    expect(failure.message, contains('ProductTile'));
  });

  scanTest('per-widget budget', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    await expectLater(
      expectRebuildBudget(tester, () => homeKey.currentState!.addToCart(),
          maxRebuildsPerWidget: <String, int>{'CartBadge': 0}),
      throwsA(isA<TestFailure>().having((TestFailure f) => f.message, 'message',
          contains('Expected CartBadge to rebuild at most 0 times, got 1.'))),
    );
  });

  testWidgets('outside scanTest it says what to do',
      (WidgetTester tester) async {
    await expectLater(
      expectRebuildBudget(tester, () {}),
      throwsA(isA<TestFailure>().having(
          (TestFailure f) => f.message, 'message', contains('use scanTest('))),
    );
  });
}
