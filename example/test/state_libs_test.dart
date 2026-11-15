import 'package:flutter_test/flutter_test.dart';
import 'package:why_rebuild/testing.dart';
import 'package:why_rebuild_example/main.dart';
import 'package:why_rebuild_example/state_demos.dart';

final WhyRebuild scan = WhyRebuild.instance;

CallSite? site(String widget) {
  final List<CallSite> sites = scan.why(widget).callSites;
  return sites.isEmpty ? null : sites.first;
}

String onlyTrigger(CallSite site) => site.triggers.keys.single;

void main() {
  scanTest('demo app: the three demo problems', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    homeKey.currentState!.addToCart();
    await tester.pump();
    keyboardKey.currentState!.toggleKeyboard();
    await tester.pump();

    expect(scan.appPackage, 'why_rebuild_example');
    final CallSite tile = site('ProductTile')!;
    expect(tile.location, startsWith('lib/main.dart:'));
    expect(
      onlyTrigger(tile),
      startsWith('setState in HomePageState.addToCart at lib/main.dart:'),
    );
    expect(tile.wasted, tile.rebuilds);
    expect(site('CheckoutForm')!.fixHint, contains('MediaQuery.sizeOf'));
  });

  scanTest('provider: watch() names the provider and the model method', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 3; i++) {
      cartModel.add();
      await tester.pump();
    }

    final CallSite view = site('ProviderCartView')!;
    expect(view.rebuilds, 3);
    expect(view.causes, <String, int>{'inherited': 3});
    expect(view.changedDependencies, <String, int>{'Provider<CartModel>': 3});
    expect(onlyTrigger(view), contains('Provider<CartModel> changed'));
    expect(
      onlyTrigger(view),
      contains('CartModel.add at lib/state_demos.dart:'),
    );

    expect(site('ExpensiveRow')!.wasted, 3, reason: 'label never changes');
    expect(
      site('ProviderOwnerView'),
      isNull,
      reason: 'select() on a constant field',
    );
  });

  scanTest('riverpod: ref.watch names Riverpod and the notifier method', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 3; i++) {
      riverpodContainer.read(counterProvider.notifier).increment();
      await tester.pump();
    }

    final CallSite view = site('RiverpodCounterView')!;
    expect(view.rebuilds, 3);
    expect(view.causes, <String, int>{'stateLibrary': 3});
    expect(
      onlyTrigger(view),
      contains('Riverpod notified RiverpodCounterView'),
    );
    expect(onlyTrigger(view), contains('Counter.increment'));
    expect(
      site('RiverpodSelectView'),
      isNull,
      reason: 'select() result unchanged',
    );
  });

  scanTest('bloc: BlocBuilder setState points at the BlocBuilder call site', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    for (int i = 0; i < 3; i++) {
      counterCubit.increment();
      // Cubit state arrives through a stream (a microtask later).
      await tester.pump();
      await tester.pump();
    }

    final CallSite builder = site('BlocBuilder')!;
    expect(builder.rebuilds, 3);
    expect(builder.causes, <String, int>{'stateLibrary': 3});
    expect(
      onlyTrigger(builder),
      startsWith(
        'setState in BlocBuilder<CounterCubit, int> (package:flutter_bloc) at lib/state_demos.dart:',
      ),
    );
  });

  scanTest('GetX: Obx', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    getxCount.value++;
    await tester.pump();
    await tester.pump();

    final CallSite obx = site('Obx')!;
    expect(obx.causes.keys.single, 'stateLibrary');
    expect(
      onlyTrigger(obx),
      startsWith('setState in Obx (package:get) at lib/state_demos.dart:'),
    );
    expect(obx.location, startsWith('lib/state_demos.dart:'));
  });

  scanTest('MobX: Observer', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    incrementMobx();
    await tester.pump();

    final CallSite observer = site('Observer')!;
    expect(observer.causes.keys.single, 'stateLibrary');
    expect(
      onlyTrigger(observer),
      startsWith('MobX notified Observer after incrementMobx'),
    );
  });

  scanTest('signals: SignalBuilder', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    signalCount.value++;
    await tester.pump();
    await tester.pump();

    final CallSite builder = site('SignalBuilder')!;
    expect(builder.causes.keys.single, 'stateLibrary');
    expect(onlyTrigger(builder), contains('Signals'));
  });

  scanTest('flutter_hooks: useState', (WidgetTester tester) async {
    await tester.pumpWidget(const DemoApp());
    hooksCounter!.value++;
    await tester.pump();

    final CallSite view = site('HooksCounterView')!;
    expect(view.causes.keys.single, 'stateLibrary');
    expect(
      onlyTrigger(view),
      startsWith('flutter_hooks notified HooksCounterView'),
    );
  });

  scanTest('every library: the unchanged child rows are flagged as wasted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    cartModel.add();
    riverpodContainer.read(counterProvider.notifier).increment();
    counterCubit.increment();
    getxCount.value++;
    incrementMobx();
    signalCount.value++;
    hooksCounter!.value++;
    await tester.pump();
    await tester.pump();

    // One call site per library demo.
    final WhyReport rows = scan.why('ExpensiveRow');
    expect(rows.callSites, hasLength(7));
    expect(rows.rebuilds, 7);
    expect(rows.wasted, 7);
    for (final CallSite row in rows.callSites) {
      expect(row.fixHint, contains('Make it const'));
    }
  });

  scanTest('budget: a provider update must not rebuild unrelated widgets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await expectRebuildBudget(
      tester,
      cartModel.add,
      maxRebuildsPerWidget: <String, int>{
        'ProductTile': 0,
        'RiverpodCounterView': 0,
      },
    );
  });
}
