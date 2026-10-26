#!/usr/bin/env python3
"""Lets your Pixpaw pet answer Claude Code for you.

A Claude Code hook. For a permission prompt (PermissionRequest) or a question
(PreToolUse on AskUserQuestion), it leaves the question for Pixpaw in
~/Library/Application Support/Pixpaw/asks/<id>.json, opens
<scheme>://droplet/pixpaw/ask?id=<id> in the background, and waits for the
answer you click on the pet's card. Then it hands Claude the answer.

When the pet isn't out to answer, nobody clicks within PIXPAW_ASK_WAIT
seconds (default 110), or you click "Answer in Claude instead", it prints
nothing and Claude asks you as usual. It never answers on its own.

    "PermissionRequest": [{"hooks": [{"type": "command", "timeout": 120,
        "command": "PIXPAW_SCHEME=droppy python3 /path/to/pixpaw-ask.py"}]}],
    "PreToolUse": [{"matcher": "AskUserQuestion", "hooks": [{"type": "command", "timeout": 120,
        "command": "PIXPAW_SCHEME=droppy python3 /path/to/pixpaw-ask.py"}]}]

PIXPAW_SCHEME picks the host: droppy-playground (default) or droppy.
"""

import json
import os
import signal
import subprocess
import sys
import time
import urllib.parse
import uuid

FOLDER = os.path.expanduser("~/Library/Application Support/Pixpaw/asks")
SCHEME = os.environ.get("PIXPAW_SCHEME", "droppy-playground")
WAIT = float(os.environ.get("PIXPAW_ASK_WAIT", "110"))
AGENT = "Claude"


def short(text, limit):
    text = " ".join(str(text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def pet_is_out():
    """The pet touches `alive` every 15 seconds while it's out to answer."""
    try:
        return time.time() - os.path.getmtime(os.path.join(FOLDER, "alive")) < 45
    except OSError:
        return False


def describe(tool, args):
    """What Claude wants to do, as a title and the thing it's about."""
    args = args if isinstance(args, dict) else {}
    if tool == "Bash":
        return "Run this command?", args.get("command")
    if tool in ("Edit", "MultiEdit", "Write", "NotebookEdit"):
        path = args.get("file_path") or args.get("notebook_path") or ""
        return ("Create this file?" if tool == "Write" else "Edit this file?"), os.path.basename(path) or path
    if tool == "WebFetch":
        url = args.get("url") or ""
        return "Open this page?", urllib.parse.urlparse(url).netloc or url
    if tool == "WebSearch":
        return "Search the web?", args.get("query")
    if tool.startswith("mcp__"):
        parts = tool.split("__")
        return f"Use {parts[-1]}?", parts[1] if len(parts) > 2 else None
    return f"Use {tool}?", None


def permission(event):
    tool = event.get("tool_name") or ""
    # Questions and plans have prompts of their own.
    if tool in ("AskUserQuestion", "ExitPlanMode"):
        return None
    title, detail = describe(tool, event.get("tool_input"))
    always = next((s for s in event.get("permission_suggestions") or []
                   if s.get("type") == "addRules" and s.get("behavior") == "allow"), None)
    options = ["Allow"] + (["Always allow"] if always else []) + ["Deny"]

    def reply(choice):
        if choice == "Allow":
            decision = {"behavior": "allow"}
        elif choice == "Always allow":
            decision = {"behavior": "allow", "updatedPermissions": [always]}
        elif choice == "Deny":
            decision = {"behavior": "deny", "message": "Denied from Pixpaw."}
        else:
            return None
        return {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}}

    spoken = f"{AGENT} needs you. {title}"
    return {"title": title, "detail": short(detail, 240) if detail else None, "options": options, "spoken": spoken}, reply


def question(event):
    if event.get("tool_name") != "AskUserQuestion":
        return None
    args = event.get("tool_input") or {}
    questions = args.get("questions") or []
    # One question with a single answer fits the card; more, Claude asks.
    if len(questions) != 1 or questions[0].get("multiSelect"):
        return None
    asked = questions[0]
    labels = [o.get("label") for o in asked.get("options") or [] if o.get("label")]
    if not labels or len(labels) > 4:
        return None

    def reply(choice):
        if choice not in labels:
            return None
        return {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "updatedInput": dict(args, answers={asked.get("question", ""): choice}),
        }}

    text = short(asked.get("question"), 120)
    return {"title": text, "detail": None, "options": labels, "spoken": f"{AGENT} asks: {text}"}, reply


def main():
    try:
        event = json.load(sys.stdin)
    except Exception:
        return
    if not pet_is_out():
        return
    kind = event.get("hook_event_name")
    found = permission(event) if kind == "PermissionRequest" else question(event) if kind == "PreToolUse" else None
    if not found:
        return
    card, reply = found

    ask_id = str(uuid.uuid4())
    request = os.path.join(FOLDER, ask_id + ".json")
    answer = os.path.join(FOLDER, ask_id + ".answer")

    def clean(*_):
        for path in (request, answer):
            try:
                os.remove(path)
            except OSError:
                pass
        if _:
            sys.exit(0)

    # Claude stops waiting (you answered there): take the card down.
    signal.signal(signal.SIGTERM, clean)
    signal.signal(signal.SIGINT, clean)
    signal.signal(signal.SIGHUP, clean)
    try:
        os.makedirs(FOLDER, exist_ok=True)
        place = os.path.basename(event.get("cwd") or "") or None
        body = dict(card, id=ask_id, agent=AGENT, place=place)
        partial = request + ".part"
        with open(partial, "w") as f:
            json.dump(body, f)
        os.replace(partial, request)
        subprocess.Popen(["open", "-g", f"{SCHEME}://droplet/pixpaw/ask?id={ask_id}"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        end = time.time() + WAIT
        choice = None
        while time.time() < end:
            if os.path.exists(answer):
                with open(answer) as f:
                    choice = f.read().strip()
                break
            time.sleep(0.25)
        output = reply(choice) if choice else None
        if output:
            print(json.dumps(output))
    finally:
        clean()


if __name__ == "__main__":
    main()
