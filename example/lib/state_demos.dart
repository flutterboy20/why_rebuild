// Scenarios for popular state management packages. Each one has a
// widget that SHOULD rebuild (it shows the value) and an ExpensiveRow inside it
// that should NOT (its props never change), plus a "selective" widget that
// listens to something that does not change.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' as getx;
import 'package:mobx/mobx.dart' as mobx;
import 'package:provider/provider.dart' as p;
import 'package:signals/signals_flutter.dart' as signals;

// ---------------------------------------------------------------------------
// provider

class CartModel extends ChangeNotifier {
  int count = 0;
  final String owner = 'Ada';

  void add() {
    count++;
    notifyListeners();
  }
}

final CartModel cartModel = CartModel();

class ProviderCartView extends StatelessWidget {
  const ProviderCartView({super.key});

  @override
  Widget build(BuildContext context) {
    final int count = context.watch<CartModel>().count;
    return Column(
      children: <Widget>[
        Text('provider count: $count'),
        ExpensiveRow(label: 'provider row'),
      ],
    );
  }
}

/// Uses select() on a field that never changes, so it should never rebuild.
class ProviderOwnerView extends StatelessWidget {
  const ProviderOwnerView({super.key});

  @override
  Widget build(BuildContext context) {
    final String owner = context.select((CartModel m) => m.owner);
    return Text('owner: $owner');
  }
}

// ---------------------------------------------------------------------------
// riverpod

class Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final NotifierProvider<Counter, int> counterProvider =
    NotifierProvider<Counter, int>(Counter.new);
final ProviderContainer riverpodContainer = ProviderContainer();

class RiverpodCounterView extends ConsumerWidget {
  const RiverpodCounterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(counterProvider);
    return Column(
      children: <Widget>[
        Text('riverpod count: $count'),
        ExpensiveRow(label: 'riverpod row'),
      ],
    );
  }
}

/// Watches only whether the count is above 1000, so it should not rebuild.
class RiverpodSelectView extends ConsumerWidget {
  const RiverpodSelectView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool big = ref.watch(counterProvider.select((int c) => c > 1000));
    return Text('riverpod big: $big');
  }
}

// ---------------------------------------------------------------------------
// bloc

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}

final CounterCubit counterCubit = CounterCubit();

class BlocCounterView extends StatelessWidget {
  const BlocCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterCubit, int>(
      builder: (BuildContext context, int count) {
        return Column(
          children: <Widget>[
            Text('bloc count: $count'),
            ExpensiveRow(label: 'bloc row'),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// GetX

final getx.RxInt getxCount = getx.RxInt(0);

class GetxCounterView extends StatelessWidget {
  const GetxCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return getx.Obx(
      () => Column(
        children: <Widget>[
          Text('getx count: ${getxCount.value}'),
          ExpensiveRow(label: 'getx row'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MobX (no code generation)

final mobx.Observable<int> mobxCount = mobx.Observable<int>(0);

void incrementMobx() => mobx.runInAction(() => mobxCount.value++);

class MobxCounterView extends StatelessWidget {
  const MobxCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (BuildContext context) => Column(
        children: <Widget>[
          Text('mobx count: ${mobxCount.value}'),
          ExpensiveRow(label: 'mobx row'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// signals

final signals.Signal<int> signalCount = signals.signal<int>(0);

class SignalsCounterView extends StatelessWidget {
  const SignalsCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return signals.SignalBuilder(
      builder: (BuildContext context) => Column(
        children: <Widget>[
          Text('signals count: ${signalCount.value}'),
          ExpensiveRow(label: 'signals row'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// flutter_hooks

/// The useState notifier, exposed so tests and ext.example.trigger can bump it.
ValueNotifier<int>? hooksCounter;

class HooksCounterView extends HookWidget {
  const HooksCounterView({super.key});

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<int> count = useState(0);
    hooksCounter = count;
    return Column(
      children: <Widget>[
        Text('hooks count: ${count.value}'),
        ExpensiveRow(label: 'hooks row'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class ExpensiveRow extends StatelessWidget {
  const ExpensiveRow({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}

/// Wraps [child] with all three packages' scopes, using global instances so
/// tests and the ext.poc.trigger extension can drive them.
class StateScopes extends StatelessWidget {
  const StateScopes({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: riverpodContainer,
      child: p.ChangeNotifierProvider<CartModel>.value(
        value: cartModel,
        child: BlocProvider<CounterCubit>.value(
          value: counterCubit,
          child: child,
        ),
      ),
    );
  }
}

class StateDemos extends StatelessWidget {
  const StateDemos({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        ProviderCartView(),
        ProviderOwnerView(),
        RiverpodCounterView(),
        RiverpodSelectView(),
        BlocCounterView(),
        GetxCounterView(),
        MobxCounterView(),
        SignalsCounterView(),
        HooksCounterView(),
      ],
    );
  }
}
