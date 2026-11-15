## 0.1.0

First release.

- `WhyRebuild.instance.install()`: records why each app widget rebuilt (setState,
  InheritedWidget, listenable/animation, state library, parent cascade), whether
  the rebuild was wasted, and a fix hint.
- Detects provider, Riverpod, Bloc, GetX, MobX, signals and flutter_hooks from
  stack frames, without importing them.
- Typed results: `report()`, `why()`, `wasted()`, `status()`, all with `toJson()`.
- VM service extensions `ext.why_rebuild.status|record|report|why|reset|pause|resume`
  for DevTools, the Dart MCP server and AI agents. `why` without a widget lists
  the widgets with wasted rebuilds.
- `package:why_rebuild/testing.dart`: `scanTest` and `expectRebuildBudget`.
- Safe by design: debug-only, steps aside for DevTools "Count widget builds",
  never overwrites another tool's hook, detaches after repeated internal errors,
  falls back to lite mode if stack capture stops working, warns once per
  problem, no-op on web.
- Agent skill in `skills/why_rebuild-debugging/SKILL.md`.
