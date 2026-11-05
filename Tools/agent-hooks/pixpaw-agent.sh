#!/bin/bash
# Tells Pixpaw what a coding agent is doing.
#
#   pixpaw-agent.sh <name> <working|done|waiting|error> [text]
#   pixpaw-agent.sh <name> tool           (PreToolUse: the tool and its file)
#   pixpaw-agent.sh <name> tool-done      (PostToolUse, PostToolUseFailure:
#                                          whether a command worked)
#   pixpaw-agent.sh <name> helper         (SubagentStart, SubagentStop: a
#                                          helper sent off, and back)
#   pixpaw-agent.sh --codex '<json>'      (Codex `notify`: the JSON is the last argument)
#
# Hook events arrive with JSON on stdin; when it carries a "message" (Claude
# Code's Notification hook) that becomes the text. When an agent is done, the
# plan usage it has left goes along (from usage.py), so the cat can say it.
# For Claude, scheduled.py tells a scheduled run (a Desktop scheduled task or
# a /loop) from your own, and adds its name and, at the end, its result.
# In a Git repository, antigravity/workspace.py (shared with the Antigravity
# plugin, which is copied on its own when installed) notes where HEAD is when a turn starts and,
# when it's done, how much changed ("3 files · +84 −12"): counts only. A
# command that starts a dev server sends the port it will be on.
# Opens <scheme>://droplet/pixpaw/agent?… in the background and returns at
# once, so it never slows the agent down. PIXPAW_SCHEME picks the host:
# droppy-playground (default) or droppy.

here="$(cd "$(dirname "$0")" && pwd)"
scheme="${PIXPAW_SCHEME:-droppy-playground}"
usage=""
diff=""

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
  input=""
  [ ! -t 0 ] && input=$(cat)
  if [ "$state" = "tool" ]; then
    # Only the tool's name and the least of what it touches leave here: a
    # file's name without its folders, a command's first two words (past a
    # leading `cd … &&`), a web address's host. Nothing else of it, but
    # for a command that starts a dev server, the port it will be on, and
    # for a `git push` to GitHub, the repository and branch.
    query=$(printf '%s' "$input" | python3 -c 'import json, os, sys, urllib.parse as u
sys.path.insert(0, sys.argv[2])
from workspace import dev_ports, pushed_to
try: event = json.load(sys.stdin)
except Exception: sys.exit()
tool = str(event.get("tool_name") or "")
given = event.get("tool_input") if isinstance(event.get("tool_input"), dict) else {}
target = ""
if given.get("file_path") or given.get("notebook_path"):
    target = os.path.basename(str(given.get("file_path") or given.get("notebook_path")))
elif given.get("command"):
    words = str(given["command"]).split()
    if words[:1] == ["cd"] and "&&" in words: words = words[words.index("&&") + 1:]
    target = " ".join(words[:2])
elif given.get("url"):
    target = "https://" + (u.urlsplit(str(given["url"])).hostname or "")
call = str(event.get("tool_use_id") or "")[:80]
ports = ",".join(map(str, dev_ports(given.get("command")))) if tool == "Bash" else ""
ci = pushed_to(given.get("command"), str(event.get("cwd") or "")) if tool == "Bash" else ""
if tool: print(u.urlencode({k: v for k, v in {"name": sys.argv[1], "state": "tool", "tool": tool[:64], "target": target[:100], "id": call, "ports": ports, "ci": ci}.items() if v}))' "$name" "$here/antigravity" 2>/dev/null)
    [ -n "$query" ] && open -g "$scheme://droplet/pixpaw/agent?$query" >/dev/null 2>&1 &
    exit 0
  fi
  if [ "$state" = "tool-done" ] || [ "$state" = "helper" ]; then
    # Only which call it was, by the agent's own id, and how it went:
    # nothing of the command, its output or the helper's work.
    query=$(printf '%s' "$input" | python3 -c 'import json, sys, urllib.parse as u
try: event = json.load(sys.stdin)
except Exception: sys.exit()
hook = str(event.get("hook_event_name") or "")
pairs = {"name": sys.argv[1], "state": sys.argv[2]}
if sys.argv[2] == "helper":
    pairs.update(event="done" if hook == "SubagentStop" else "start", id=str(event.get("agent_id") or "")[:80])
else:
    given = event.get("tool_response") if isinstance(event.get("tool_response"), dict) else {}
    stopped = event.get("is_interrupt") or given.get("interrupted")
    outcome = "stopped" if stopped else "failed" if hook == "PostToolUseFailure" else "ok"
    pairs.update(tool=str(event.get("tool_name") or "")[:64], id=str(event.get("tool_use_id") or "")[:80], outcome=outcome)
print(u.urlencode({k: v for k, v in pairs.items() if v}))' "$name" "$state" 2>/dev/null)
    [ -n "$query" ] && open -g "$scheme://droplet/pixpaw/agent?$query" >/dev/null 2>&1 &
    exit 0
  fi
  if [ -z "$text" ] && [ -n "$input" ]; then
    text=$(printf '%s' "$input" | python3 -c 'import json,sys
try: print((json.load(sys.stdin).get("message") or "").replace("\n"," ")[:90])
except Exception: pass' 2>/dev/null)
  fi
  if [ "$name" = "Claude" ] && [ -n "$input" ]; then
    scheduled=$(printf '%s' "$input" | python3 "$here/scheduled.py" "$state" 2>/dev/null)
  fi
  if [ "$state" = "done" ] && [ "$name" = "Claude" ]; then
    usage=$(python3 "$here/usage.py" claude-left 2>/dev/null)
  fi
  # What the turn changed in the project, counted from where HEAD was when
  # it began: "3 files · +84 −12". Numbers only.
  if [ -n "$input" ] && { [ "$state" = "working" ] || [ "$state" = "done" ]; }; then
    turn=$(printf '%s' "$input" | python3 -c 'import json,sys
try: e = json.load(sys.stdin)
except Exception: e = {}
print(str(e.get("session_id") or ""), str(e.get("cwd") or ""), sep="\n")' 2>/dev/null)
    session=$(printf '%s\n' "$turn" | sed -n 1p); folder=$(printf '%s\n' "$turn" | sed -n 2p)
    if [ -n "$session" ]; then
      if [ "$state" = "working" ]; then
        python3 "$here/antigravity/workspace.py" turn-start "$name-$session" "$folder" >/dev/null 2>&1
      else
        diff=$(python3 "$here/antigravity/workspace.py" turn-diff "$name-$session" "$folder" 2>/dev/null)
      fi
    fi
  fi
fi

[ -z "$name" ] || [ -z "$state" ] && exit 0
query=$(python3 -c 'import sys, urllib.parse as u
pairs = {"name": sys.argv[1], "state": sys.argv[2], "text": sys.argv[3], "usage": sys.argv[4], "diff": sys.argv[5]}
print(u.urlencode({k: v for k, v in pairs.items() if v}))' "$name" "$state" "$text" "$usage" "$diff")
[ -n "$scheduled" ] && query="$query&$scheduled"
open -g "$scheme://droplet/pixpaw/agent?$query" >/dev/null 2>&1 &
exit 0
