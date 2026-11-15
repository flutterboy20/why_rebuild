server: {"name": "dart and flutter tooling", "version": "1.2.2", "description": "Connects Dart and Flutter apps and developer tools to AI agents."}
tools: rip_grep_packages, read_package_uris, dtd, get_runtime_errors, hot_restart, hot_reload, widget_inspector, flutter_driver_command, vm_service, pub_dev_search, pub, roots, analyze_files, lsp

### connect
request: {"command": "connect", "appUri": "ws://127.0.0.1:53077/_fXUycsyi4w=/ws"}
isError: None
Successfully connected to ws://127.0.0.1:53077/_fXUycsyi4w=/ws.

### getVM
request: {"command": "callMethod", "method": "getVM"}
isError: None
{
  "type": "VM",
  "name": "vm",
  "architectureBits": 64,
  "hostCPU": "12th Gen Intel(R) Core(TM) i7-12",
  "operatingSystem": "windows",
  "targetCPU": "x64",
  "version": "3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on \"windows_x64\"",
  "_features": "release no-asan no-msan no-tsan no-shared_data asserts use_field_guards use_osr branch_coverage coverage no-code_comments no-dwarf_stack_traces x64 windows no-compressed-pointers",
  "_profilerMode": "VM",
  "pid": 469036,
  "startTime": 1794246874331,
  "_embedder": "Flutter",
  "_maxRSS": 318181376,
  "_currentRSS": 314204160,
  "isolates": [
    {
      "type": "@Isolate",
      "id": "isolates/5967973218903487",
      "name": "main",
      "number": "5967973218903487",
      "isSystemIsolate": false,
      "isolateGroupId": "isolateGroups/1782215538775723"
    }
  ],
  "systemIsolates": [
    {
      "type": "@Isolate",
      "id": "isolates/5623542438093243",
      "name": "vm-service",
      "number": "5623542438093243",
      "isSystemIsolate": true,
      "isolateGroupId": "isolateGroups/1885175173528233"
    }
  ],
  "isolateGroups": [
    {
      "type": "@IsolateGroup",
      "id": "isolateGroups/1782215538775723",
      "name": "main.dart",
      "number": "1782215538775723",
      "isSystemIsolateGroup": false
    }
  ],
  "systemIsolateGroups": [
    {
      "type": "@IsolateGroup",
      "id": "isolateGroups/1885175173528233",
      "name": "vm-service",
      "number": "1885175173528233",
      "isSystemIsolateGroup": true
    }
  ],
  "_currentMemory": 158470144
}

### status (start)
request: {"command": "callMethod", "method": "ext.why_rebuild.status", "isolateId": "isolates/5967973218903487"}
isError: None
{
  "state": "recording",
  "mode": "full",
  "framesWithRebuilds": 2,
  "rebuildsRecorded": 0,
  "widgetsTracked": 0
}

### record start
request: {"command": "callMethod", "method": "ext.why_rebuild.record", "isolateId": "isolates/5967973218903487", "arguments": {"action": "start"}}
isError: None
{
  "state": "recording",
  "mode": "full",
  "framesWithRebuilds": 0,
  "rebuildsRecorded": 0,
  "widgetsTracked": 0
}

### trigger cart x3
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "cart", "times": "3"}}
isError: None
{
  "scenario": "cart",
  "times": 3
}

### trigger keyboard x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "keyboard", "times": "2"}}
isError: None
{
  "scenario": "keyboard",
  "times": 2
}

### provider x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "provider", "times": "2"}}
isError: None
{
  "scenario": "provider",
  "times": 2
}

### riverpod x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "riverpod", "times": "2"}}
isError: None
{
  "scenario": "riverpod",
  "times": 2
}

### bloc x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "bloc", "times": "2"}}
isError: None
{
  "scenario": "bloc",
  "times": 2
}

### getx x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "getx", "times": "2"}}
isError: None
{
  "scenario": "getx",
  "times": 2
}

### mobx x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "mobx", "times": "2"}}
isError: None
{
  "scenario": "mobx",
  "times": 2
}

### signals x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "signals", "times": "2"}}
isError: None
{
  "scenario": "signals",
  "times": 2
}

### hooks x2
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "hooks", "times": "2"}}
isError: None
{
  "scenario": "hooks",
  "times": 2
}

### spinner start
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "spinnerStart"}}
isError: None
{
  "scenario": "spinnerStart",
  "times": 1
}

### spinner stop
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "spinnerStop"}}
isError: None
{
  "scenario": "spinnerStop",
  "times": 1
}

### record stop (returns report)
request: {"command": "callMethod", "method": "ext.why_rebuild.record", "isolateId": "isolates/5967973218903487", "arguments": {"action": "stop", "limit": "6"}}
isError: None
{
  "state": "paused",
  "mode": "full",
  "framesWithRebuilds": 56,
  "top": [
    {
      "widget": "AnimatedBuilder",
      "location": "lib/main.dart:295",
      "rebuilds": 40,
      "wasted": 3,
      "cause": "listenable",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "ChartCard",
      "location": "lib/main.dart:301",
      "rebuilds": 40,
      "wasted": 40,
      "cause": "parent rebuilt (AnimatedBuilder)",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "Text",
      "location": "lib/main.dart:314",
      "rebuilds": 40,
      "wasted": 40,
      "cause": "parent rebuilt (AnimatedBuilder)",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "ProductTile",
      "location": "lib/main.dart:171",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "ListTile",
      "location": "lib/main.dart:202",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "Text",
      "location": "lib/main.dart:202",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    }
  ]
}

### why ProductTile
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ProductTile"}}
isError: None
{
  "widget": "ProductTile",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:171",
      "rebuilds": 15,
      "wasted": 15,
      "causes": {
        "parent rebuilt (HomePage)": 15
      },
      "triggers": {
        "setState in HomePageState.addToCart at lib/main.dart:162": 15
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (setState in HomePageState.addToCart at lib/main.dart:162) into a smaller widget."
    }
  ]
}

### why PlainTile
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "PlainTile"}}
isError: None
{
  "widget": "PlainTile",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:172",
      "rebuilds": 3,
      "wasted": 0,
      "propsUnknown": 3,
      "causes": {
        "parent rebuilt (HomePage)": 3
      },
      "triggers": {
        "setState in HomePageState.addToCart at lib/main.dart:162": 3
      },
      "fixHint": "Props could not be compared (the widget has no debugFillProperties). Add debugFillProperties so why_rebuild can detect wasted rebuilds."
    }
  ]
}

### why CartBadge
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "CartBadge"}}
isError: None
{
  "widget": "CartBadge",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:170",
      "rebuilds": 3,
      "wasted": 0,
      "causes": {
        "parent rebuilt (HomePage)": 3
      },
      "triggers": {
        "setState in HomePageState.addToCart at lib/main.dart:162": 3
      },
      "fixHint": null
    }
  ]
}

### why CheckoutForm
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "CheckoutForm"}}
isError: None
{
  "widget": "CheckoutForm",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:173",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "inherited": 2
      },
      "triggers": {
        "MediaQuery changed": 2
      },
      "changedDependencies": {
        "MediaQuery": 2
      },
      "fixHint": "Depends on all of MediaQuery, so any change (keyboard insets, padding) rebuilds it. If it only needs the size, use MediaQuery.sizeOf(context) (or paddingOf, viewInsetsOf, ...)."
    }
  ]
}

### why CheckoutFormFixed
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "CheckoutFormFixed"}}
isError: None
{
  "widget": "CheckoutFormFixed",
  "mode": "full",
  "callSites": []
}

### why ChartCard
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ChartCard"}}
isError: None
{
  "widget": "ChartCard",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:301",
      "rebuilds": 40,
      "wasted": 40,
      "causes": {
        "parent rebuilt (HomePage)": 3,
        "parent rebuilt (AnimatedBuilder)": 37
      },
      "triggers": {
        "setState in HomePageState.addToCart at lib/main.dart:162": 3,
        "animation tick in AnimatedBuilder at lib/main.dart:295": 37
      },
      "fixHint": "Rebuilt on every animation tick with unchanged props. Build it once and pass it as AnimatedBuilder(child: ...)."
    }
  ]
}

### why ProviderCartView
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ProviderCartView"}}
isError: None
{
  "widget": "ProviderCartView",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:254",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "inherited": 2
      },
      "triggers": {
        "Provider<CartModel> changed (provider notified Provider<CartModel> after CartModel.add at lib/state_demos.dart:26)": 2
      },
      "changedDependencies": {
        "Provider<CartModel>": 2
      },
      "fixHint": null
    }
  ]
}

### why ProviderOwnerView
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ProviderOwnerView"}}
isError: None
{
  "widget": "ProviderOwnerView",
  "mode": "full",
  "callSites": []
}

### why RiverpodCounterView
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "RiverpodCounterView"}}
isError: None
{
  "widget": "RiverpodCounterView",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:256",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "Riverpod notified RiverpodCounterView after Counter.increment at lib/state_demos.dart:65": 2
      },
      "changedDependencies": {
        "Riverpod ProviderScope": 2
      },
      "fixHint": null
    }
  ]
}

### why RiverpodSelectView
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "RiverpodSelectView"}}
isError: None
{
  "widget": "RiverpodSelectView",
  "mode": "full",
  "callSites": []
}

### why BlocBuilder
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "BlocBuilder"}}
isError: None
{
  "widget": "BlocBuilder",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:113",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "setState in BlocBuilder<CounterCubit, int> (package:flutter_bloc) at lib/state_demos.dart:113": 2
      },
      "changedDependencies": {
        "Provider<CounterCubit>": 2
      },
      "fixHint": null
    }
  ]
}

### why Obx
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "Obx"}}
isError: None
{
  "widget": "Obx",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:136",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "setState in Obx (package:get) at lib/state_demos.dart:136": 2
      },
      "fixHint": null
    }
  ]
}

### why Observer
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "Observer"}}
isError: None
{
  "widget": "Observer",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:159",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "MobX notified Observer after incrementMobx at lib/state_demos.dart:152": 2
      },
      "fixHint": null
    }
  ]
}

### why SignalBuilder
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "SignalBuilder"}}
isError: None
{
  "widget": "SignalBuilder",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:180",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "Signals notified SignalBuilder after _registerDemoTriggers at lib/main.dart:105": 2
      },
      "fixHint": null
    }
  ]
}

### why HooksCounterView
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "HooksCounterView"}}
isError: None
{
  "widget": "HooksCounterView",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:262",
      "rebuilds": 2,
      "wasted": 0,
      "causes": {
        "stateLibrary": 2
      },
      "triggers": {
        "flutter_hooks notified HooksCounterView after _registerDemoTriggers at lib/main.dart:107": 2
      },
      "fixHint": null
    }
  ]
}

### why ExpensiveRow
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ExpensiveRow"}}
isError: None
{
  "widget": "ExpensiveRow",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/state_demos.dart:41",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (ProviderCartView)": 2
      },
      "triggers": {
        "Provider<CartModel> changed (provider notified Provider<CartModel> after CartModel.add at lib/state_demos.dart:26)": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (Provider<CartModel> changed (provider notified Provider<CartModel> after CartModel.add at lib/state_demos.dart:26)) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:80",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (RiverpodCounterView)": 2
      },
      "triggers": {
        "Riverpod notified RiverpodCounterView after Counter.increment at lib/state_demos.dart:65": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (Riverpod notified RiverpodCounterView after Counter.increment at lib/state_demos.dart:65) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:207",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (HooksCounterView)": 2
      },
      "triggers": {
        "flutter_hooks notified HooksCounterView after _registerDemoTriggers at lib/main.dart:107": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (flutter_hooks notified HooksCounterView after _registerDemoTriggers at lib/main.dart:107) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:118",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (BlocBuilder<CounterCubit, int>)": 2
      },
      "triggers": {
        "setState in BlocBuilder<CounterCubit, int> (package:flutter_bloc) at lib/state_demos.dart:113": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (setState in BlocBuilder<CounterCubit, int> (package:flutter_bloc) at lib/state_demos.dart:113) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:140",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (Obx)": 2
      },
      "triggers": {
        "setState in Obx (package:get) at lib/state_demos.dart:136": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (setState in Obx (package:get) at lib/state_demos.dart:136) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:163",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (Observer)": 2
      },
      "triggers": {
        "MobX notified Observer after incrementMobx at lib/state_demos.dart:152": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (MobX notified Observer after incrementMobx at lib/state_demos.dart:152) into a smaller widget."
    },
    {
      "location": "lib/state_demos.dart:184",
      "rebuilds": 2,
      "wasted": 2,
      "causes": {
        "parent rebuilt (SignalBuilder)": 2
      },
      "triggers": {
        "Signals notified SignalBuilder after _registerDemoTriggers at lib/main.dart:105": 2
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (Signals notified SignalBuilder after _registerDemoTriggers at lib/main.dart:105) into a smaller widget."
    }
  ]
}

### why with no widget arg (wasted list)
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487"}
isError: None
{
  "mode": "full",
  "note": "Ask why(widget) for causes and a fix hint.",
  "wastedWidgets": [
    {
      "widget": "ChartCard",
      "location": "lib/main.dart:301",
      "rebuilds": 40,
      "wasted": 40,
      "cause": "parent rebuilt (AnimatedBuilder)",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "Text",
      "location": "lib/main.dart:314",
      "rebuilds": 40,
      "wasted": 40,
      "cause": "parent rebuilt (AnimatedBuilder)",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "ProductTile",
      "location": "lib/main.dart:171",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "ListTile",
      "location": "lib/main.dart:202",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "Text",
      "location": "lib/main.dart:202",
      "rebuilds": 15,
      "wasted": 15,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "Text",
      "location": "lib/state_demos.dart:220",
      "rebuilds": 14,
      "wasted": 14,
      "cause": "parent rebuilt (ProviderCartView)",
      "trigger": "Provider<CartModel> changed (provider notified Provider<CartModel> after CartModel.add at lib/state_demos.dart:26)"
    },
    {
      "widget": "AnimatedBuilder",
      "location": "lib/main.dart:295",
      "rebuilds": 40,
      "wasted": 3,
      "cause": "listenable",
      "trigger": "animation tick in AnimatedBuilder at lib/main.dart:295"
    },
    {
      "widget": "ListView",
      "location": "lib/main.dart:167",
      "rebuilds": 3,
      "wasted": 3,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "Text",
      "location": "lib/main.dart:218",
      "rebuilds": 3,
      "wasted": 3,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    },
    {
      "widget": "ElevatedButton",
      "location": "lib/main.dart:177",
      "rebuilds": 3,
      "wasted": 3,
      "cause": "parent rebuilt (HomePage)",
      "trigger": "setState in HomePageState.addToCart at lib/main.dart:162"
    }
  ]
}

### record start again
request: {"command": "callMethod", "method": "ext.why_rebuild.record", "isolateId": "isolates/5967973218903487", "arguments": {"action": "start"}}
isError: None
{
  "state": "recording",
  "mode": "full",
  "framesWithRebuilds": 0,
  "rebuildsRecorded": 0,
  "widgetsTracked": 0
}

### DevTools tracking ON while scanner records
request: {"command": "callMethod", "method": "ext.flutter.inspector.trackRebuildDirtyWidgets", "isolateId": "isolates/5967973218903487", "arguments": {"enabled": "true"}}
isError: None
{
  "enabled": "true",
  "type": "_extensionType",
  "method": "ext.flutter.inspector.trackRebuildDirtyWidgets"
}

### status while DevTools tracks
request: {"command": "callMethod", "method": "ext.why_rebuild.status", "isolateId": "isolates/5967973218903487"}
isError: None
{
  "state": "yieldedToDevTools",
  "mode": "full",
  "note": "DevTools \"Count widget builds\" is on. Recording resumes automatically when it is turned off.",
  "framesWithRebuilds": 0,
  "rebuildsRecorded": 0,
  "widgetsTracked": 0
}

### cart x2 while DevTools tracks
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "cart", "times": "2"}}
isError: None
{
  "scenario": "cart",
  "times": 2
}

### ProductTile (expect empty)
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ProductTile"}}
isError: None
{
  "widget": "ProductTile",
  "mode": "full",
  "callSites": []
}

### DevTools tracking OFF
request: {"command": "callMethod", "method": "ext.flutter.inspector.trackRebuildDirtyWidgets", "isolateId": "isolates/5967973218903487", "arguments": {"enabled": "false"}}
isError: None
{
  "enabled": "false",
  "type": "_extensionType",
  "method": "ext.flutter.inspector.trackRebuildDirtyWidgets"
}

### one frame to re-attach
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "cart"}}
isError: None
{
  "scenario": "cart",
  "times": 1
}

### status after DevTools off
request: {"command": "callMethod", "method": "ext.why_rebuild.status", "isolateId": "isolates/5967973218903487"}
isError: None
{
  "state": "recording",
  "mode": "full",
  "framesWithRebuilds": 1,
  "rebuildsRecorded": 26,
  "widgetsTracked": 14
}

### cart x2 after DevTools off
request: {"command": "callMethod", "method": "ext.example.trigger", "isolateId": "isolates/5967973218903487", "arguments": {"scenario": "cart", "times": "2"}}
isError: None
{
  "scenario": "cart",
  "times": 2
}

### ProductTile (expect counts again)
request: {"command": "callMethod", "method": "ext.why_rebuild.why", "isolateId": "isolates/5967973218903487", "arguments": {"widget": "ProductTile"}}
isError: None
{
  "widget": "ProductTile",
  "mode": "full",
  "callSites": [
    {
      "location": "lib/main.dart:171",
      "rebuilds": 15,
      "wasted": 15,
      "causes": {
        "parent rebuilt (HomePage)": 15
      },
      "triggers": {
        "setState in HomePageState.addToCart at lib/main.dart:162": 15
      },
      "fixHint": "Rebuilt only because an ancestor rebuilt; its props never changed. Make it const, or move the state that changes (setState in HomePageState.addToCart at lib/main.dart:162) into a smaller widget."
    }
  ]
}

### DevTools ON again (second round)
request: {"command": "callMethod", "method": "ext.flutter.inspector.trackRebuildDirtyWidgets", "isolateId": "isolates/5967973218903487", "arguments": {"enabled": "true"}}
isError: None
{
  "enabled": "true",
  "type": "_extensionType",
  "method": "ext.flutter.inspector.trackRebuildDirtyWidgets"
}

### status second round
request: {"command": "callMethod", "method": "ext.why_rebuild.status", "isolateId": "isolates/5967973218903487"}
isError: None
{
  "state": "yieldedToDevTools",
  "mode": "full",
  "note": "DevTools \"Count widget builds\" is on. Recording resumes automatically when it is turned off.",
  "framesWithRebuilds": 3,
  "rebuildsRecorded": 78,
  "widgetsTracked": 14
}

### DevTools OFF again
request: {"command": "callMethod", "method": "ext.flutter.inspector.trackRebuildDirtyWidgets", "isolateId": "isolates/5967973218903487", "arguments": {"enabled": "false"}}
isError: None
{
  "enabled": "false",
  "type": "_extensionType",
  "method": "ext.flutter.inspector.trackRebuildDirtyWidgets"
}

### overhead: 30 tiles
request: {"command": "callMethod", "method": "ext.example.bench", "isolateId": "isolates/5967973218903487", "arguments": {"frames": "60", "tiles": "30"}}
isError: None
{
  "tiles": 30,
  "frames": 60,
  "medianBuildMsOff": "6.74",
  "medianBuildMsOn": "7.93",
  "slowdown": "1.2x"
}

### overhead: 200 tiles
request: {"command": "callMethod", "method": "ext.example.bench", "isolateId": "isolates/5967973218903487", "arguments": {"frames": "60", "tiles": "200"}}
isError: None
{
  "tiles": 200,
  "frames": 60,
  "medianBuildMsOff": "3.61",
  "medianBuildMsOn": "4.83",
  "slowdown": "1.3x"
}
