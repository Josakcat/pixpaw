#!/usr/bin/env python3
"""Tells Pixpaw what Google Antigravity is doing.

Run by this folder's hooks.json once it is installed as an Antigravity plugin
(`agy plugin install /path/to/Tools/agent-hooks/antigravity`), which covers
the Antigravity app, the IDE and the agy CLI alike:

    antigravity.py working   PreInvocation: a turn starts
    antigravity.py tool      PreToolUse: what it's about to do, for the tag
                             at the pet's side
    antigravity.py done      Stop: finished, or failed

It always prints nothing. A PreToolUse hook that prints a decision changes
what Antigravity allows (an empty `{}` even blocks the tool), so this one
leaves every decision to Antigravity, exactly as without it.

An Automation (a scheduled task: ~/.gemini/config/sidecars/*/sidecar.json
with "builtin": "schedule") is told from your own runs by its prompt; its
name goes along, and when it's done, the first line of its answer.

When a turn is done, the plan usage left goes along too ("5h 76% · week 59%
left", for the models in use), from `agy -p /usage`. That takes a few
seconds, so a child of this hook asks and tells Pixpaw, and the hook returns
at once. The answer is kept for a minute, so a busy afternoon asks once a
minute at most, and the `agy` it runs is never followed back in here.

Opens <scheme>://droplet/pixpaw/agent?… in the background and returns at
once. PIXPAW_SCHEME picks the host; without it, Droppy when it is installed,
else Droppy Playground.
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse as u

NAME = "Antigravity"
SIDECARS = os.path.expanduser("~/.gemini/config/sidecars")
USAGE = os.path.expanduser("~/Library/Application Support/Pixpaw/antigravity-usage.json")
QUIET = "PIXPAW_ASKING_USAGE"
FAILED = {"ERROR", "MAX_INVOCATIONS", "MAX_FORCED_INVOCATIONS", "MAX_TOKEN_BUDGET_EXCEEDED"}

# Antigravity's tools by the names Pixpaw knows them by (Claude Code's).
TOOLS = {
    "read_file": "Read", "view_file": "Read", "view_content_chunk": "Read", "read_notebook": "Read",
    "edit_file": "Edit", "replace_file_content": "Edit", "multi_replace_file_content": "Edit", "edit_notebook": "Edit",
    "write_to_file": "Write", "write_file": "Write",
    "run_command": "Bash",
    "grep_search": "Grep", "find_by_name": "Grep", "code_search": "Grep", "find": "Grep",
    "search_web": "WebSearch",
    "read_url_content": "WebFetch", "read_url": "WebFetch",
    "invoke_subagent": "Task", "browser_subagent": "Task",
}


def scheme():
    if os.environ.get("PIXPAW_SCHEME"):
        return os.environ["PIXPAW_SCHEME"]
    return "droppy" if os.path.exists("/Applications/Droppy.app") else "droppy-playground"


def tell(**pairs):
    query = u.urlencode({k: v for k, v in pairs.items() if v})
    subprocess.Popen(["open", "-g", f"{scheme()}://droplet/pixpaw/agent?{query}"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def plain(text):
    return " ".join(str(text or "").split()).lower()


def short(text, limit):
    text = " ".join(str(text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def automation(asked):
    """The Automation whose prompt started this run, by its name."""
    said = plain(asked)
    if not said:
        return None
    for path in glob.glob(os.path.join(SIDECARS, "*", "sidecar.json")):
        try:
            sidecar = json.load(open(path, encoding="utf-8"))
        except Exception:
            continue
        if sidecar.get("builtin") != "schedule":
            continue
        args = [str(a) for a in sidecar.get("args") or []]
        prompt = " ".join(args[args.index("--") + 1:]) if "--" in args else (args[-1] if args else "")
        start = plain(prompt)[:160]
        if start and start in said:
            return sidecar.get("display_name") or os.path.basename(os.path.dirname(path))
    return None


def answer(transcript):
    """The first line that says something in the run's last reply."""
    last = ""
    try:
        with open(transcript, encoding="utf-8") as f:
            for line in f:
                try:
                    step = json.loads(line)
                except Exception:
                    continue
                if step.get("source") == "MODEL" and step.get("type") == "PLANNER_RESPONSE" and step.get("content"):
                    last = step["content"]
    except (OSError, TypeError):
        return ""
    lines = [l for l in last.splitlines() if l.strip()]
    said = [l for l in lines if not l.lstrip().startswith("#")] or lines
    first = said[0] if said else ""
    # Markdown links keep their text; marks go.
    first = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", first)
    return short(re.sub(r"^[#>*\-\s]+|[*`_]", "", first).strip(), 140)


def usage_left(model):
    """What's left of the plan for the models in use, e.g. "5h 76% · week
    59% left"; asked of agy at most once a minute."""
    try:
        kept = json.load(open(USAGE))
        if time.time() - kept["at"] < 60:
            table = kept["table"]
        else:
            raise ValueError
    except Exception:
        agy = shutil.which("agy") or os.path.expanduser("~/.local/bin/agy")
        if not os.path.exists(agy):
            return ""
        try:
            table = subprocess.run([agy, "-p", "/usage", "--print-timeout", "20s"], capture_output=True, text=True,
                                   timeout=25, env=dict(os.environ, **{QUIET: "1"})).stdout
        except Exception:
            return ""
        try:
            os.makedirs(os.path.dirname(USAGE), exist_ok=True)
            json.dump({"at": time.time(), "table": table}, open(USAGE, "w"))
        except OSError:
            pass
    # Rows: group, limit, percent left, when it resets.
    group = "claude and gpt" if re.search(r"claude|gpt", str(model), re.I) else "gemini models"
    left = {}
    for row in table.splitlines():
        cells = [c.strip() for c in row.split("\t")]
        if len(cells) >= 3 and cells[0].lower().startswith(group) and re.fullmatch(r"\d+%", cells[2]):
            if "five hour" in cells[1].lower():
                left["5h"] = cells[2]
            elif "weekly" in cells[1].lower():
                left["week"] = cells[2]
    said = " · ".join(f"{k} {left[k]}" for k in ("5h", "week") if k in left)
    return f"{said} left" if said else ""


def target(tool, args):
    """The least of what a tool touches: a file's name, a command's first
    two words (past a leading `cd … &&`), a web address's host."""
    path = next((args[k] for k in ("Path", "AbsolutePath", "TargetFile", "FilePath", "File") if args.get(k)), None)
    if path:
        return os.path.basename(str(path))
    if tool == "Bash":
        words = str(args.get("CommandLine") or "").split()
        if words[:1] == ["cd"] and "&&" in words:
            words = words[words.index("&&") + 1:]
        return " ".join(words[:2])
    if tool == "WebFetch":
        host = u.urlsplit(str(args.get("Url") or args.get("url") or "")).hostname
        return f"https://{host}" if host else ""
    return ""


def main():
    state = sys.argv[1] if len(sys.argv) > 1 else ""
    # The agy that usage_left runs: not one of your turns.
    if os.environ.get(QUIET):
        return
    if state == "usage":
        # The child: done, with what's left of the plan.
        pairs = json.loads(sys.argv[2])
        model = pairs.pop("model", "")
        tell(**pairs, usage=usage_left(model))
        return
    try:
        event = json.load(sys.stdin)
    except Exception:
        return
    asked = event.get("lastUserInput")

    if state == "working":
        # Once a turn: the first call to the model.
        if event.get("invocationNum", 0) == 0:
            tell(name=NAME, state="working", task=short(automation(asked), 40))
    elif state == "tool":
        call = event.get("toolCall") or {}
        name = str(call.get("name") or "")
        args = call.get("args") if isinstance(call.get("args"), dict) else {}
        tool = TOOLS.get(name) or ("Browser" if name.startswith("browser_") else None)
        if tool:
            tell(name=NAME, state="tool", tool=tool, target=target(tool, args)[:100])
    elif state == "done":
        failed = event.get("terminationReason") in FAILED
        task = automation(asked)
        result = (short(event.get("error"), 140) if failed else answer(event.get("transcriptPath"))) if task else ""
        pairs = {"name": NAME, "state": "error" if failed else "done", "task": short(task, 40), "result": result}
        if failed:
            return tell(**pairs)
        # Asking agy takes a few seconds: a child does it, and this returns.
        pairs["model"] = event.get("modelName") or ""
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "usage", json.dumps(pairs)],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


if __name__ == "__main__":
    main()
