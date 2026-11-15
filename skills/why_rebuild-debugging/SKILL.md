---
name: why_rebuild-debugging
description: Find and fix wasted or excessive widget rebuilds in a running Flutter app that uses package:why_rebuild. Use for questions about rebuilds, jank, slow frames, "why does this widget rebuild", or Flutter UI performance. Reads causes (setState, InheritedWidget, animation, Riverpod/Bloc/provider/GetX/MobX/signals/hooks) and fix hints through the official Dart MCP server.
---

# Debugging rebuilds with why_rebuild

`why_rebuild` records **why** each app widget rebuilt, whether the rebuild was
**wasted** (props unchanged), and a **fix hint**. You read it through VM service
extensions `ext.why_rebuild.*`, using the `vm_service` tool of the official Dart
MCP server (`dart mcp-server`). No extra server is needed.

## When to use

- The user asks why a widget rebuilds, why a screen is janky or slow, or how to
  cut rebuilds.
- After a UI change, to check it did not add wasted rebuilds.

## Prerequisites

1. The app calls `WhyRebuild.instance.install();` in `main()` after
   `WidgetsFlutterBinding.ensureInitialized()`. If not, add it (debug-only; it
   is a no-op in release builds and on web).
2. The app runs in **debug mode** on Android, iOS, or desktop (not web).
3. You know the app's VM service URI (`ws://127.0.0.1:PORT/TOKEN=/ws`, printed by
   `flutter run` as "Dart VM Service ... is available at"), or the app was
   launched through DTD so the `dtd` tool can connect.

## The loop

All extension arguments are strings.

1. Connect:
   `vm_service {"command": "connect", "appUri": "ws://127.0.0.1:PORT/TOKEN=/ws"}`
2. Get the isolate id:
   `vm_service {"command": "callMethod", "method": "getVM"}` → `isolates[0].id`
3. Start a clean recording:
   `vm_service {"command": "callMethod", "method": "ext.why_rebuild.record", "isolateId": "<id>", "arguments": {"action": "start"}}`
   Expect `"state": "recording"`. If not, read `note` (see "States").
4. Reproduce the slow flow: drive the app (`flutter_driver_command`, the app's
   own debug hooks) or ask the user to tap through it. Keep it short and focused.
5. Stop and get the report:
   `... "method": "ext.why_rebuild.record", "arguments": {"action": "stop", "limit": "10"}`
6. Find wasted rebuilds without knowing widget names:
   `... "method": "ext.why_rebuild.why"` (no arguments) → `wastedWidgets`.
7. Ask about one widget:
   `... "method": "ext.why_rebuild.why", "arguments": {"widget": "ProductTile"}`
8. Edit the code following `fixHint`, `hot_reload`, then repeat steps 3–7 to
   prove the rebuilds dropped. Report before/after numbers to the user.

Other methods: `ext.why_rebuild.status`, `report` (`limit`), `reset`, `pause`,
`resume`.

## Reading the results

`report.top[]` and `why.callSites[]` entries:

| Field | Meaning |
|---|---|
| `widget`, `location` | Widget type and where the app creates it (`lib/main.dart:153`). Edit there. |
| `rebuilds` | Rebuilds recorded (first builds not counted). |
| `wasted` | Rebuilt by its parent with identical props. Pure waste. |
| `propsUnknown` | Props could not be compared: the widget has no `debugFillProperties`. Not proof of waste. |
| `cause` / `causes` | `setState`, `inherited`, `listenable`, `stateLibrary`, `parent rebuilt (Root)`, `self`, `unknown`. |
| `trigger` / `triggers` | The root cause with `file:line`, e.g. `setState in HomePageState.addToCart at lib/main.dart:144`. For `parent` rebuilds this is the trigger of the cascade root. |
| `changedDependencies` | Inherited widgets that changed (`MediaQuery`, `Provider<CartModel>`, `Theme`). |
| `fixHint` | Suggested fix, or null when the rebuild looks legitimate. |

A widget whose cause is `setState`/`inherited`/`stateLibrary` and `wasted: 0`
usually rebuilds **legitimately** (it shows changing data). Focus on `wasted`
first, then on large `rebuilds` counts under a `parent rebuilt (...)` cause.

## Fix playbook

| Pattern | Fix |
|---|---|
| `parent rebuilt (X)`, all wasted | Make the child `const`, or move the changing state out of `X` into a smaller widget that wraps only what changes. |
| `animation tick in AnimatedBuilder`, child wasted | Build the static subtree once and pass it as `AnimatedBuilder(child: ...)` / `ListenableBuilder(child: ...)`. |
| `changedDependencies: MediaQuery` | Use `MediaQuery.sizeOf(context)` (or `paddingOf`, `viewInsetsOf`, ...) instead of `MediaQuery.of(context)`. |
| `Provider<T> changed` on a widget using one field | `context.select((T m) => m.field)` instead of `context.watch<T>()`. |
| `Riverpod notified X` too often | `ref.watch(provider.select(...))`. |
| `setState in BlocBuilder<...> (package:flutter_bloc)` too often | Add `buildWhen`, or use `BlocSelector`. |
| `setState in Obx (package:get)` | Split the `Obx` so it only wraps widgets that read the observable. |
| `propsUnknown` | Add `debugFillProperties` to the widget so waste can be measured, then re-record. |

Verify every fix by recording again: the `wasted` count of the widget should
drop to 0 (or `rebuilds` should drop).

## States (`status.state`)

- `recording`: fine.
- `paused`: call `record` with `action: start` (or `resume`).
- `yieldedToDevTools`: DevTools "Count widget builds" is on. Ask the user to
  turn it off; recording resumes by itself.
- `blockedByOtherTool`: another tool owns `debugOnRebuildDirtyWidget`. Ask the
  user which one and to turn it off.
- `disabledAfterErrors`: the scanner protected the app after internal errors.
  Restart the app; report `lastError` to the package authors.

## Lite mode: don't trust it blindly

`mode: "full"` causes come from stack traces and are exact. `mode: "lite"`
(no stacks; only used as an automatic fallback on unknown Flutter versions)
**guesses**: it can blame a `ProviderScope` or the wrong `Provider` for a
Riverpod or Bloc rebuild. When `mode` is `lite`, say so to the user, treat
causes as hints, and confirm by reading the code.

## Tests as a guard

After fixing, offer a regression test with `package:why_rebuild/testing.dart`:

```dart
scanTest('add to cart stays cheap', (tester) async {
  await tester.pumpWidget(const MyApp());
  await expectRebuildBudget(tester, () => tester.tap(find.text('Add')),
      forbidWasted: ['ProductTile']);
});
```

A failing budget prints the same causes, triggers and fix hint.

## Limits

- Debug mode only; web is not supported yet.
- Wasted detection needs `debugFillProperties` on the widget.
- Stream-driven rebuilds (Bloc, StreamBuilder) cannot name the method that
  emitted; they point at the builder widget's location instead.
- `Scaffold` removes `viewInsets` from its body's `MediaQuery`, so
  keyboard-driven rebuilds only show inside the body.
