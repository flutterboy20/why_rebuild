// Demo widgets for the core tests: the PoC scenarios that need no
// third-party package. Line numbers matter to some expectations only through
// the file name, never through exact lines.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();
final GlobalKey<KeyboardSimState> keyboardKey = GlobalKey<KeyboardSimState>();
final GlobalKey<SpinnerPanelState> spinnerKey = GlobalKey<SpinnerPanelState>();

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // KeyboardSim sits inside the Scaffold body: Scaffold removes
      // viewInsets from its body's MediaQuery.
      home: Scaffold(
        body: KeyboardSim(key: keyboardKey, child: HomePage(key: homeKey)),
      ),
    );
  }
}

// Scenario 1: setState high in the tree rebuilds every product tile.

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _cartCount = 0;

  void addToCart() {
    setState(() => _cartCount++);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        CartBadge(count: _cartCount),
        for (int i = 0; i < 3; i++) ProductTile(name: 'Product $i'),
        PlainTile(label: 'No diagnostics'),
        const CheckoutForm(),
        const CheckoutFormFixed(),
        SpinnerPanel(key: spinnerKey),
        ElevatedButton(onPressed: addToCart, child: const Text('Add to cart')),
      ],
    );
  }
}

class CartBadge extends StatelessWidget {
  const CartBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Text('Cart: $count');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('count', count));
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => ListTile(title: Text(name));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('name', name));
  }
}

/// Same shape as ProductTile but without debugFillProperties.
class PlainTile extends StatelessWidget {
  const PlainTile({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

// Scenario 2: keyboard insets change MediaQuery.

class KeyboardSim extends StatefulWidget {
  const KeyboardSim({super.key, required this.child});
  final Widget child;

  @override
  State<KeyboardSim> createState() => KeyboardSimState();
}

class KeyboardSimState extends State<KeyboardSim> {
  bool _open = false;

  void toggleKeyboard() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final MediaQueryData base = MediaQuery.of(context);
    return MediaQuery(
      data: base.copyWith(viewInsets: EdgeInsets.only(bottom: _open ? 300 : 0)),
      child: widget.child,
    );
  }
}

class CheckoutForm extends StatelessWidget {
  const CheckoutForm({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return Text('Checkout form (width ${width.round()})');
  }
}

class CheckoutFormFixed extends StatelessWidget {
  const CheckoutFormFixed({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return Text('Checkout form fixed (width ${width.round()})');
  }
}

// Scenario 3: AnimatedBuilder without `child` rebuilds a chart every tick.

class SpinnerPanel extends StatefulWidget {
  const SpinnerPanel({super.key});

  @override
  State<SpinnerPanel> createState() => SpinnerPanelState();
}

class SpinnerPanelState extends State<SpinnerPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  void start() => _controller.repeat();
  void stop() => _controller.stop();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          children: <Widget>[
            Transform.rotate(
                angle: _controller.value * 6.28,
                child: const Icon(Icons.refresh)),
            ChartCard(title: 'Revenue'),
          ],
        );
      },
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text('Chart: $title');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', title));
  }
}

/// A child widget with props, for builder tests.
class Leaf extends StatelessWidget {
  const Leaf({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}

/// A generic app widget, for `why('Holder')` matching `Holder<int>`.
class Holder<T> extends StatelessWidget {
  const Holder({super.key, required this.value});
  final T value;

  @override
  Widget build(BuildContext context) => Text('$value');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('value', value));
  }
}

/// debugFillProperties throws: the scanner must survive it.
class BrokenProps extends StatelessWidget {
  const BrokenProps({super.key});

  @override
  Widget build(BuildContext context) => const Text('broken');

  @override
  // ignore: must_call_super
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    throw StateError('broken debugFillProperties');
  }
}

/// A StatefulWidget whose setState rebuilds [child] builder output.
class Counter extends StatefulWidget {
  const Counter({super.key, required this.builder});
  final Widget Function(int count) builder;

  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) => widget.builder(count);
}
