"""One line per step of an mcp_test.py result file."""
import json
import sys

text = open(sys.argv[1], encoding="utf-8").read()
for block in text.split("\n### ")[1:]:
    title = block.split("\n")[0]
    if not (title.startswith(("why ", "overhead", "status", "DevTools", "ProductTile", "record stop"))):
        continue
    start = block.find("{", block.find("isError"))
    try:
        data, _ = json.JSONDecoder().raw_decode(block[start:])
    except Exception:
        err = [l for l in block.split("\n") if "RPCError" in l or "Failed" in l]
        print(f"- {title}: ERROR {err[:1]}")
        continue
    if "callSites" in data:
        if not data["callSites"]:
            print(f"- {title}: no rebuilds")
        for c in data["callSites"]:
            trig = "; ".join(list(c["triggers"].keys())[:2])
            print(f"- {title}: {c['rebuilds']} rebuilds, {c['wasted']} wasted | {trig} | hint: {(c.get('fixHint') or '-')[:70]}")
    elif "top" in data:
        print(f"- {title}: state={data['state']} frames={data['framesWithRebuilds']} top={[t['widget'] for t in data['top']]}")
    else:
        print(f"- {title}: " + json.dumps({k: v for k, v in data.items() if k != 'note'}))
