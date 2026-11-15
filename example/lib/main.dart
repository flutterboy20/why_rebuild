import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:why_rebuild/why_rebuild.dart';

import 'state_demos.dart';

final GlobalKey<HomePageState> homeKey = GlobalKey<HomePageState>();
final GlobalKey<KeyboardSimState> keyboardKey = GlobalKey<KeyboardSimState>();
final GlobalKey<SpinnerPanelState> spinnerKey = GlobalKey<SpinnerPanelState>();

// The three demo problems an agent should find and fix:
//  1. ProductTile rebuilt by HomePage's setState (make it const / move state).
//  2. CheckoutForm depends on all of MediaQuery (use MediaQuery.sizeOf).
//  3. ChartCard rebuilt every animation tick (AnimatedBuilder child).

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug-only; does nothing in profile/release builds and on web.
  WhyRebuild.instance.install();
  if (kDebugMode) {
    _registerDemoTriggers(); // demo-only; keeps release builds free of scanner code
  }
  runApp(const DemoApp());
}

/// Demo-only extensions so a VM service client (or an agent) can drive the
/// scenarios without clicking: ext.example.trigger and ext.example.bench.
void _registerDemoTriggers() {
  // Overhead benchmark: median UI-thread build time per frame with the scanner
  // off, on, and off again, while a setState rebuilds [tiles] product tiles.
  developer.registerExtension('ext.example.bench', (
    _,
    Map<String, String> p,
  ) async {
    final int frames = int.tryParse(p['frames'] ?? '') ?? 60;
    final int tiles = int.tryParse(p['tiles'] ?? '') ?? 200;
    homeKey.currentState!.setTiles(tiles);
    await WidgetsBinding.instance.endOfFrame;

    Future<double> run() async {
      final List<int> builds = <int>[];
      void onTimings(List<FrameTiming> timings) {
        builds.addAll(
          timings.map((FrameTiming t) => t.buildDuration.inMicroseconds),
        );
      }

      SchedulerBinding.instance.addTimingsCallback(onTimings);
      for (int i = 0; i < frames; i++) {
        homeKey.currentState!.addToCart();
        await WidgetsBinding.instance.endOfFrame;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      SchedulerBinding.instance.removeTimingsCallback(onTimings);
      if (builds.isEmpty) {
        return -1;
      }
      builds.sort();
      return builds[builds.length ~/ 2] / 1000;
    }

    final WhyRebuild scan = WhyRebuild.instance;
    scan.stopRecording();
    final double off1 = await run();
    scan.startRecording();
    final double on = await run();
    scan.stopRecording();
    final double off2 = await run();
    scan.startRecording();
    homeKey.currentState!.setTiles(5);
    final double off = (off1 + off2) / 2;
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{
        'tiles': tiles,
        'frames': frames,
        'medianBuildMsOff': off.toStringAsFixed(2),
        'medianBuildMsOn': on.toStringAsFixed(2),
        'slowdown': off > 0 ? '${(on / off).toStringAsFixed(1)}x' : 'n/a',
      }),
    );
  });

  developer.registerExtension('ext.example.trigger', (
    _,
    Map<String, String> p,
  ) async {
    final String scenario = p['scenario'] ?? '';
    final int times = int.tryParse(p['times'] ?? '') ?? 1;
    for (int i = 0; i < times; i++) {
      switch (scenario) {
        case 'cart':
          homeKey.currentState!.addToCart();
        case 'keyboard':
          keyboardKey.currentState!.toggleKeyboard();
        case 'spinnerStart':
          spinnerKey.currentState!.start();
        case 'spinnerStop':
          spinnerKey.currentState!.stop();
        case 'provider':
          cartModel.add();
        case 'riverpod':
          riverpodContainer.read(counterProvider.notifier).increment();
        case 'bloc':
          counterCubit.increment();
        case 'getx':
          getxCount.value++;
        case 'mobx':
          incrementMobx();
        case 'signals':
          signalCount.value++;
        case 'hooks':
          hooksCounter?.value++;
        case 'tiles':
          homeKey.currentState!.setTiles(int.tryParse(p['count'] ?? '') ?? 5);
        default:
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'unknown scenario',
          );
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return developer.ServiceExtensionResponse.result(
      jsonEncode(<String, Object?>{'scenario': scenario, 'times': times}),
    );
  });
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'why_rebuild example',
      // KeyboardSim sits inside the Scaffold body: Scaffold removes
      // viewInsets from its body's MediaQuery, so outside it would be hidden.
      home: StateScopes(
        child: Scaffold(
          body: KeyboardSim(
            key: keyboardKey,
            child: HomePage(key: homeKey),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scenario 1: setState high in the tree rebuilds every product tile.

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _cartCount = 0;
  int _tiles = 5;

  void setTiles(int count) => setState(() => _tiles = count);

  void addToCart() {
    setState(() => _cartCount++);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        CartBadge(count: _cartCount),
        for (int i = 0; i < _tiles; i++) ProductTile(name: 'Product $i'),
        PlainTile(label: 'No diagnostics'),
        const CheckoutForm(),
        const CheckoutFormFixed(),
        SpinnerPanel(key: spinnerKey),
        const StateDemos(),
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

/// Same shape as ProductTile but without debugFillProperties, to show the
/// limit of props comparison.
class PlainTile extends StatelessWidget {
  const PlainTile({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

// ---------------------------------------------------------------------------
// Scenario 2: keyboard insets change MediaQuery; widgets that call
// MediaQuery.of rebuild even though they only need the size.

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

// ---------------------------------------------------------------------------
// Scenario 3: AnimatedBuilder without `child` rebuilds a heavy chart each tick.

class SpinnerPanel extends StatefulWidget {
  const SpinnerPanel({super.key});

  @override
  State<SpinnerPanel> createState() => SpinnerPanelState();
}

class SpinnerPanelState extends State<SpinnerPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

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
              child: const Icon(Icons.refresh),
            ),
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
