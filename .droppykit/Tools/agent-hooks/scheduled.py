#!/usr/bin/env python3
"""Tells a scheduled run of Claude Code from one you started yourself.

Called by pixpaw-agent.sh with the hook's state (working, done, error) and
the hook's JSON on stdin. Prints the extra query for Pixpaw, `task=…` and
`result=…`, when the run is a scheduled one:

- a Desktop scheduled task: its prompt is the body of
  ~/.claude/scheduled-tasks/<name>/SKILL.md;
- a /loop or other cron in a session: its prompt is one of the Stop hook's
  `session_crons`.

The prompt that started each turn is kept for a day in
~/Library/Application Support/Pixpaw/runs/<session>.json, so the Stop hook
knows which run just finished. Prints nothing for an ordinary turn.
"""

import glob
import json
import os
import re
import sys
import time
import urllib.parse

RUNS = os.path.expanduser("~/Library/Application Support/Pixpaw/runs")
TASKS = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")), "scheduled-tasks")


def plain(text):
    return " ".join(str(text or "").split()).lower()


def short(text, limit):
    text = " ".join(str(text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def scheduled_task(prompt):
    """The Desktop scheduled task whose prompt this is, by its name."""
    said = plain(prompt)
    if not said:
        return None
    for path in glob.glob(os.path.join(TASKS, "*", "SKILL.md")):
        folder = os.path.basename(os.path.dirname(path))
        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        name = folder
        body = text
        front = re.match(r"^---\s*\n(.*?)\n---\s*\n?", text, re.S)
        if front:
            body = text[front.end():]
            found = re.search(r"^name:\s*(.+)$", front.group(1), re.M)
            if found:
                name = found.group(1).strip().strip("\"'")
        start = plain(body)[:160]
        if (start and start in said) or said.startswith("/" + folder.lower()) or f"scheduled-tasks/{folder.lower()}" in said:
            return name
    return None


def remember(session, record):
    os.makedirs(RUNS, exist_ok=True)
    # A day is plenty; old ones go.
    for old in glob.glob(os.path.join(RUNS, "*.json")):
        try:
            if time.time() - os.path.getmtime(old) > 86400:
                os.remove(old)
        except OSError:
            pass
    with open(os.path.join(RUNS, session + ".json"), "w") as f:
        json.dump(record, f)


def recall(session):
    try:
        return json.load(open(os.path.join(RUNS, session + ".json")))
    except Exception:
        return {}


def main():
    state = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        event = json.load(sys.stdin)
    except Exception:
        return
    session = re.sub(r"[^A-Za-z0-9-]", "", str(event.get("session_id") or ""))[:64]
    if not session:
        return

    if state == "working":
        prompt = event.get("prompt") or ""
        remember(session, {"prompt": prompt[:2000], "task": scheduled_task(prompt)})
        task = recall(session).get("task")
        if task:
            print(urllib.parse.urlencode({"task": short(task, 40)}))
        return

    if state in ("done", "error"):
        record = recall(session)
        task = record.get("task")
        if not task:
            # A /loop or cron firing in this session.
            asked = plain(record.get("prompt"))
            for cron in event.get("session_crons") or []:
                if asked and plain(cron.get("prompt")).rstrip("…").strip()[:200] in asked:
                    task = "Loop: " + short(cron.get("prompt"), 30)
                    break
        if not task:
            return
        result = event.get("last_assistant_message") or event.get("error") or ""
        # The first line that says something, past any heading, without
        # Markdown marks.
        raw = [l for l in str(result).splitlines() if l.strip()]
        said = [l for l in raw if not l.lstrip().startswith("#")] or raw
        first = re.sub(r"^[#>*\-\s]+|[*`_]", "", said[0]).strip() if said else ""
        print(urllib.parse.urlencode({"task": short(task, 40), "result": short(first, 140)}))


if __name__ == "__main__":
    main()
