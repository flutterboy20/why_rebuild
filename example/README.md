# why_rebuild example

Demo app for `package:why_rebuild`.

- **Three classic problems**: `HomePage.setState` rebuilds every `ProductTile`
  (wasted), `CheckoutForm` uses `MediaQuery.of` only for the size, and
  `ChartCard` rebuilds on every `AnimatedBuilder` tick.
- **State libraries**: provider, Riverpod, Bloc, GetX, MobX, signals and
  flutter_hooks, each with a counter view and an `ExpensiveRow` that never
  changes.

`ext.example.trigger` (`scenario=cart|keyboard|spinnerStart|spinnerStop|provider|riverpod|bloc|getx|mobx|signals|hooks`, `times?`)
drives the scenarios over the VM service; `ext.example.bench` measures the
scanner's overhead. `../tool/run_live.ps1 -Device <id> -Out <file>` runs the
whole scenario list through `dart mcp-server`.

```
flutter run
flutter test
```
