"""Drive the official Dart MCP server (dart mcp-server) over stdio, exactly as
an agent like Claude Code would, and call the package's ext.why_rebuild.*
service extensions through its vm_service tool."""
import json
import os
import shutil
import subprocess
import sys

# The Dart SDK that provides `dart mcp-server`. Override with the DART env var.
DART = os.environ.get("DART") or shutil.which("dart") or "dart"
APP_URI = sys.argv[1]
OUT = sys.argv[2]

proc = subprocess.Popen(
    [DART, "mcp-server", "--log-file", OUT + ".traffic.log"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    text=True, encoding="utf-8", bufsize=1,
)
log = open(OUT, "w", encoding="utf-8")
_id = 0


def rpc(method, params=None, notify=False):
    global _id
    msg = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        msg["params"] = params
    if not notify:
        _id += 1
        msg["id"] = _id
    proc.stdin.write(json.dumps(msg) + "\n")
    proc.stdin.flush()
    if notify:
        return None
    while True:
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError("server closed: " + proc.stderr.read())
        resp = json.loads(line)
        if resp.get("id") == _id:
            return resp


def tool(args, label):
    resp = rpc("tools/call", {"name": "vm_service", "arguments": args})
    result = resp.get("result", resp)
    text = "\n".join(c.get("text", "") for c in result.get("content", []))
    log.write(f"\n### {label}\nrequest: {json.dumps(args)}\n"
              f"isError: {result.get('isError')}\n")
    try:
        log.write(json.dumps(json.loads(text), indent=2) + "\n")
    except Exception:
        log.write(text + "\n")
    log.flush()
    return result, text


init = rpc("initialize", {
    "protocolVersion": "2025-06-18",
    "capabilities": {},
    "clientInfo": {"name": "why-rebuild-live-test", "version": "0.0.1"},
})
log.write("server: " + json.dumps(init["result"]["serverInfo"]) + "\n")
rpc("notifications/initialized", notify=True)

tools = rpc("tools/list")["result"]["tools"]
names = [t["name"] for t in tools]
log.write("tools: " + ", ".join(names) + "\n")

tool({"command": "connect", "appUri": APP_URI}, "connect")
_, vm = tool({"command": "callMethod", "method": "getVM"}, "getVM")
isolate = json.loads(vm)["isolates"][0]["id"]


def call(method, label, **arguments):
    args = {"command": "callMethod", "method": method, "isolateId": isolate}
    if arguments:
        args["arguments"] = {k: str(v) for k, v in arguments.items()}
    return tool(args, label)


import time

call("ext.why_rebuild.status", "status (start)")

# Agent-style session: start recording, reproduce, stop -> report.
call("ext.why_rebuild.record", "record start", action="start")
call("ext.example.trigger", "trigger cart x3", scenario="cart", times=3)
call("ext.example.trigger", "trigger keyboard x2", scenario="keyboard", times=2)
call("ext.example.trigger", "provider x2", scenario="provider", times=2)
call("ext.example.trigger", "riverpod x2", scenario="riverpod", times=2)
call("ext.example.trigger", "bloc x2", scenario="bloc", times=2)
for lib in ["getx", "mobx", "signals", "hooks"]:
    call("ext.example.trigger", f"{lib} x2", scenario=lib, times=2)
call("ext.example.trigger", "spinner start", scenario="spinnerStart")
time.sleep(0.6)
call("ext.example.trigger", "spinner stop", scenario="spinnerStop")
call("ext.why_rebuild.record", "record stop (returns report)", action="stop", limit=6)
for w in ["ProductTile", "PlainTile", "CartBadge", "CheckoutForm",
          "CheckoutFormFixed", "ChartCard", "ProviderCartView",
          "ProviderOwnerView", "RiverpodCounterView", "RiverpodSelectView",
          "BlocBuilder", "Obx", "Observer", "SignalBuilder", "HooksCounterView",
          "ExpensiveRow"]:
    call("ext.why_rebuild.why", f"why {w}", widget=w)
call("ext.why_rebuild.why", "why with no widget arg (wasted list)")

# DevTools hand-off, using the REAL inspector toggle DevTools uses for
# "Count widget builds" (Performance > Rebuild Stats).
call("ext.why_rebuild.record", "record start again", action="start")
call("ext.flutter.inspector.trackRebuildDirtyWidgets",
     "DevTools tracking ON while scanner records", enabled="true")
call("ext.why_rebuild.status", "status while DevTools tracks")
call("ext.example.trigger", "cart x2 while DevTools tracks", scenario="cart", times=2)
call("ext.why_rebuild.why", "ProductTile (expect empty)", widget="ProductTile")
call("ext.flutter.inspector.trackRebuildDirtyWidgets",
     "DevTools tracking OFF", enabled="false")
time.sleep(0.3)
call("ext.example.trigger", "one frame to re-attach", scenario="cart")
call("ext.why_rebuild.status", "status after DevTools off")
call("ext.example.trigger", "cart x2 after DevTools off", scenario="cart", times=2)
call("ext.why_rebuild.why", "ProductTile (expect counts again)", widget="ProductTile")
call("ext.flutter.inspector.trackRebuildDirtyWidgets",
     "DevTools ON again (second round)", enabled="true")
call("ext.why_rebuild.status", "status second round")
call("ext.flutter.inspector.trackRebuildDirtyWidgets",
     "DevTools OFF again", enabled="false")

if "--bench" in sys.argv:
    call("ext.example.bench", "overhead: 30 tiles", frames=60, tiles=30)
    call("ext.example.bench", "overhead: 200 tiles", frames=60, tiles=200)

proc.stdin.close()
proc.terminate()
log.close()
print("done")
