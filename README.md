# why_rebuild

[![CI](https://github.com/flutterboy20/why_rebuild/actions/workflows/ci.yml/badge.svg)](https://github.com/flutterboy20/why_rebuild/actions/workflows/ci.yml)

**DevTools shows *what* rebuilt. why_rebuild shows *why*, and your AI agent can ask it too.**

A debug-only Flutter package that tells you, for every app widget rebuild:

- **the cause**: which `setState`, which `InheritedWidget` (and why *it* changed), which animation, or which state library (provider, Riverpod, Bloc, GetX, MobX, signals, flutter_hooks);
- **the trigger**, with `file:line`;
- whether the rebuild was **wasted** (the widget's props did not change);
- **how to fix it**.

Zero config: one line in `main()`, no wrapper widgets.

```json
{"widget": "ProductTile", "mode": "full", "callSites": [{
  "location": "lib/main.dart:153", "rebuilds": 15, "wasted": 15,
  "causes": {"parent rebuilt (HomePage)": 15},
  "triggers": {"setState in HomePageState.addToCart at lib/main.dart:144": 15},
  "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (…) into a smaller widget."}]}
```

<!-- TODO: 20-second GIF: an agent finds and fixes a wasted rebuild. -->

## Install

```yaml
dev_dependencies: # or dependencies; it compiles to nothing outside debug
  why_rebuild: ^0.1.0
```

```dart
import 'package:why_rebuild/why_rebuild.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WhyRebuild.instance.install(); // debug-only; no-op in profile/release and on web
  runApp(const MyApp());
}
```

If you keep it in `dev_dependencies`, import it only from a debug entry point
(for example `lib/main_debug.dart`).

## Use it

### From Dart

```dart
final scan = WhyRebuild.instance;
print(scan.report(limit: 5));       // most rebuilt widgets, top cause and trigger
print(scan.why('ProductTile'));     // causes, triggers, wasted count, fix hint
print(scan.wasted());               // widgets with wasted rebuilds
scan.reset();
```

### From your AI agent (Claude Code, Cursor, ...)

The data is exposed as VM service extensions, reachable through the official
Dart MCP server (`dart mcp-server`, ships with the Dart SDK) and its
`vm_service` tool. No extra MCP server needed.

| Method | Params | Returns |
|---|---|---|
| `ext.why_rebuild.status` | | state, mode, counts, note |
| `ext.why_rebuild.record` | `action=start\|stop`, `limit?` | start: status (clears data); stop: report |
| `ext.why_rebuild.report` | `limit?` | most rebuilt widgets |
| `ext.why_rebuild.why` | `widget?` | causes for one widget; without `widget`, the widgets with wasted rebuilds |
| `ext.why_rebuild.reset` / `pause` / `resume` | | status |

A ready-made agent skill lives in
[`skills/why_rebuild-debugging/SKILL.md`](skills/why_rebuild-debugging/SKILL.md):
copy it into your agent's skills folder (for example `.claude/skills/`).

### In tests

```dart
import 'package:why_rebuild/testing.dart';

scanTest('add to cart stays cheap', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectRebuildBudget(tester, () => tester.tap(find.text('Add')),
      maxRebuilds: 30, forbidWasted: ['ProductTile']);
});
```

A failing budget prints the cause chain and the fix hint:

```
Expected no wasted rebuilds of ProductTile, got 3.
ProductTile (lib/main.dart:153): 3 rebuilds, 3 wasted
  cause:   parent rebuilt (HomePage) x3
  trigger: setState in HomePageState.addToCart at lib/main.dart:144 x3
  fix:     Rebuilt only because an ancestor rebuilt; its props never changed. ...
```

Use `scanTest` instead of `testWidgets`: flutter_test checks the framework's
debug globals right after the test body, so the scanner must be installed and
removed inside it.

## Causes

| `cause` | Meaning |
|---|---|
| `setState` | App code called `setState` (trigger = caller method + `file:line`). |
| `parent rebuilt (X)` | An ancestor rebuilt and passed a new widget; trigger = the root cause of that cascade. Framework roots are named with the nearest app widget (`AnimatedBuilder under MyPage`). |
| `inherited` | An `InheritedWidget` it depends on changed, chained to why it changed: `Provider<CartModel> changed (… after CartModel.add at lib/state.dart:21)`. |
| `listenable` | Animation tick, `Listenable`, `ValueListenableBuilder`, or a new `StreamBuilder`/`FutureBuilder` snapshot. |
| `stateLibrary` | A state library rebuilt it: `Riverpod notified X after Counter.increment`, `setState in BlocBuilder<…> (package:flutter_bloc)`. |
| `self` / `unknown` | Lite mode guess / nothing matched. |

**Wasted** = rebuilt by its parent with identical diagnostic properties
(`debugFillProperties`). Widgets without diagnostic properties are reported as
`propsUnknown`, never as wasted.

## It never breaks your app

- Debug mode only. In profile and release builds all scanner logic is
  tree-shaken; only an empty `WhyRebuild` class shell remains. Wrap the call in
  `if (kDebugMode)` if you want nothing at all.
- Every hook is wrapped in `try/catch`; after 20 internal errors it detaches
  itself (`disabledAfterErrors`).
- **DevTools**: when you turn on "Count widget builds", why_rebuild steps aside
  automatically (`yieldedToDevTools`) and comes back when you turn it off.
- Never overwrites a rebuild hook owned by another tool (`blockedByOtherTool`).
- Your own `debugPrint` output is forwarded untouched; no console output by
  default; each problem is reported once.
- If stack capture stops working on a future Flutter version it falls back to
  lite mode and says so in `status`.
- Hot reload and hot restart safe.

## Support

| | |
|---|---|
| Flutter | 3.27 and newer |
| Android, iOS | supported (debug mode) |
| Windows, macOS, Linux | works (same engine) |
| Web | not yet: `install()` prints one warning and does nothing |

Overhead in debug mode: about 1.1–1.5x build time per frame while recording.

## Limitations

- Wasted detection needs `debugFillProperties` on your widgets.
- Stream-driven rebuilds (Bloc, `StreamBuilder`) cannot name the method that
  emitted across the async gap; they point at the builder's location.
- Stack labels are matched by `element.toString()`; identical stateless
  widgets can share an entry (they share the cause anyway).
- Without a readable `package_config.json` (on devices), third-party code is
  recognised by pub-cache path patterns.
- `Scaffold` removes `viewInsets` from its body's `MediaQuery`, so
  keyboard-driven rebuilds only show inside the body.

## Example

[`example/`](example/) is a demo app with the three classic problems
(setState high in the tree, `MediaQuery.of` for the size, `AnimatedBuilder`
without `child`) plus provider, Riverpod, Bloc, GetX, MobX, signals and
flutter_hooks scenarios. `tool/run_live.ps1` runs it on a device and drives it
through `dart mcp-server` exactly like an agent.
