#!/bin/bash
# Tells Pixpaw what a coding agent is doing.
#
#   pixpaw-agent.sh <name> <working|done|waiting|error> [text]
#   pixpaw-agent.sh --codex '<json>'      (Codex `notify`: the JSON is the last argument)
#
# Hook events arrive with JSON on stdin; when it carries a "message" (Claude
# Code's Notification hook) that becomes the text. When an agent is done, the
# plan usage it has left goes along (from usage.py), so the cat can say it.
# Opens <scheme>://droplet/pixpaw/agent?… in the background and returns at
# once, so it never slows the agent down. PIXPAW_SCHEME picks the host:
# droppy-playground (default) or droppy.

here="$(cd "$(dirname "$0")" && pwd)"
scheme="${PIXPAW_SCHEME:-droppy-playground}"
usage=""

if [ "$1" = "--codex" ]; then
  payload="${@: -1}"
  name="Codex"; text=""
  state=$(python3 -c 'import json,sys
try: kind = json.loads(sys.argv[1]).get("type", "")
except Exception: kind = ""
print("done" if kind == "agent-turn-complete" else "waiting")' "$payload")
  [ "$state" = "done" ] && usage=$(python3 "$here/usage.py" codex-left 2>/dev/null)
else
  name="$1"; state="$2"; text="${3:-}"
  if [ -z "$text" ] && [ ! -t 0 ]; then
    text=$(python3 -c 'import json,sys
try: print((json.load(sys.stdin).get("message") or "").replace("\n"," ")[:90])
except Exception: pass' 2>/dev/null)
  fi
  if [ "$state" = "done" ] && [ "$name" = "Claude" ]; then
    usage=$(python3 "$here/usage.py" claude-left 2>/dev/null)
  fi
fi

[ -z "$name" ] || [ -z "$state" ] && exit 0
query=$(python3 -c 'import sys, urllib.parse as u
pairs = {"name": sys.argv[1], "state": sys.argv[2], "text": sys.argv[3], "usage": sys.argv[4]}
print(u.urlencode({k: v for k, v in pairs.items() if v}))' "$name" "$state" "$text" "$usage")
open -g "$scheme://droplet/pixpaw/agent?$query" >/dev/null 2>&1 &
exit 0
