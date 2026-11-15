// Treated as third-party code by the tests (CodeOrigin.debugThirdPartyPaths),
// to stand in for a library widget that rebuilds app widgets.

import 'package:flutter/widgets.dart';

class LibraryPanel extends StatelessWidget {
  const LibraryPanel(
      {super.key, required this.notifier, required this.builder});
  final ValueNotifier<int> notifier;
  final Widget Function(int value) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: notifier,
        builder: (BuildContext context, int v, Widget? child) => builder(v),
      );
}
